import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/dispatch_benchmark_presenter.dart';
import '../application/dispatch_clipboard_service.dart';
import '../application/dispatch_snapshot_file_service.dart';
import '../infrastructure/intelligence/news_intelligence_service.dart';
export 'dispatch_models.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/intelligence/triage_policy.dart';
import 'dispatch_models.dart';
import 'onyx_surface.dart';

part 'dispatch_page_snapshot_inspector.dart';
part 'dispatch_page_preset_import.dart';
part 'dispatch_page_dialog_support.dart';
part 'dispatch_page_filter_presets.dart';

class DispatchPage extends StatefulWidget {
  final String clientId;
  final String regionId;
  final String siteId;
  final VoidCallback onGenerate;
  final VoidCallback onIngestFeeds;
  final VoidCallback? onIngestNews;
  final VoidCallback? onLoadFeedFile;
  final ValueChanged<IntelligenceReceived>? onEscalateIntelligence;
  final List<String> configuredNewsSources;
  final String? newsSourceRequirementsHint;
  final List<NewsSourceDiagnostic> newsSourceDiagnostics;
  final ValueChanged<String>? onProbeNewsSource;
  final VoidCallback? onStartLivePolling;
  final VoidCallback? onStopLivePolling;
  final bool livePolling;
  final String? livePollingLabel;
  final String? runtimeConfigHint;
  final bool supabaseReady;
  final bool guardSyncBackendEnabled;
  final String telemetryProviderReadiness;
  final String? telemetryProviderActiveId;
  final String telemetryProviderExpectedId;
  final bool telemetryAdapterStubMode;
  final bool telemetryLiveReadyGateEnabled;
  final bool telemetryLiveReadyGateViolation;
  final String? telemetryLiveReadyGateReason;
  final List<String> livePollingHistory;
  final Future<void> Function(IntakeStressProfile profile) onRunStress;
  final Future<void> Function(IntakeStressProfile profile) onRunSoak;
  final Future<void> Function() onRunBenchmarkSuite;
  final IntakeStressProfile initialProfile;
  final String initialScenarioLabel;
  final List<String> initialScenarioTags;
  final String initialRunNote;
  final List<DispatchBenchmarkFilterPreset> initialFilterPresets;
  final String initialIntelligenceSourceFilter;
  final String initialIntelligenceActionFilter;
  final List<String> initialPinnedWatchIntelligenceIds;
  final List<String> initialDismissedIntelligenceIds;
  final bool initialShowPinnedWatchIntelligenceOnly;
  final bool initialShowDismissedIntelligenceOnly;
  final String initialSelectedIntelligenceId;
  final ValueChanged<IntakeStressProfile> onProfileChanged;
  final void Function(String scenarioLabel, List<String> tags)
  onScenarioChanged;
  final ValueChanged<String> onRunNoteChanged;
  final ValueChanged<List<DispatchBenchmarkFilterPreset>>?
  onFilterPresetsChanged;
  final void Function(String sourceFilter, String actionFilter)?
  onIntelligenceFiltersChanged;
  final void Function(
    List<String> pinnedWatchIntelligenceIds,
    List<String> dismissedIntelligenceIds,
  )?
  onIntelligenceTriageChanged;
  final void Function(
    bool showPinnedWatchIntelligenceOnly,
    bool showDismissedIntelligenceOnly,
  )?
  onIntelligenceViewModesChanged;
  final ValueChanged<String>? onSelectedIntelligenceChanged;
  final ValueChanged<IntakeTelemetry> onTelemetryImported;
  final Future<void> Function()? onRerunLastProfile;
  final VoidCallback onCancelStress;
  final VoidCallback onResetTelemetry;
  final VoidCallback onClearTelemetryPersistence;
  final VoidCallback? onClearLivePollHealth;
  final VoidCallback onClearProfilePersistence;
  final VoidCallback? onClearSavedViewsPersistence;
  final bool stressRunning;
  final String? intakeStatus;
  final String? stressStatus;
  final IntakeTelemetry? intakeTelemetry;
  final List<DispatchEvent> events;
  final void Function(String dispatchId) onExecute;

  const DispatchPage({
    super.key,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.onGenerate,
    required this.onIngestFeeds,
    this.onIngestNews,
    this.onLoadFeedFile,
    this.onEscalateIntelligence,
    this.configuredNewsSources = const [],
    this.newsSourceRequirementsHint,
    this.newsSourceDiagnostics = const [],
    this.onProbeNewsSource,
    this.onStartLivePolling,
    this.onStopLivePolling,
    this.livePolling = false,
    this.livePollingLabel,
    this.runtimeConfigHint,
    this.supabaseReady = false,
    this.guardSyncBackendEnabled = false,
    this.telemetryProviderReadiness = 'unknown',
    this.telemetryProviderActiveId,
    this.telemetryProviderExpectedId = 'unknown',
    this.telemetryAdapterStubMode = true,
    this.telemetryLiveReadyGateEnabled = false,
    this.telemetryLiveReadyGateViolation = false,
    this.telemetryLiveReadyGateReason,
    this.livePollingHistory = const [],
    required this.onRunStress,
    required this.onRunSoak,
    required this.onRunBenchmarkSuite,
    required this.initialProfile,
    this.initialScenarioLabel = '',
    this.initialScenarioTags = const [],
    this.initialRunNote = '',
    this.initialFilterPresets = const [],
    this.initialIntelligenceSourceFilter = 'all',
    this.initialIntelligenceActionFilter = 'all',
    this.initialPinnedWatchIntelligenceIds = const [],
    this.initialDismissedIntelligenceIds = const [],
    this.initialShowPinnedWatchIntelligenceOnly = false,
    this.initialShowDismissedIntelligenceOnly = false,
    this.initialSelectedIntelligenceId = '',
    required this.onProfileChanged,
    required this.onScenarioChanged,
    required this.onRunNoteChanged,
    this.onFilterPresetsChanged,
    this.onIntelligenceFiltersChanged,
    this.onIntelligenceTriageChanged,
    this.onIntelligenceViewModesChanged,
    this.onSelectedIntelligenceChanged,
    required this.onTelemetryImported,
    this.onRerunLastProfile,
    required this.onCancelStress,
    required this.onResetTelemetry,
    required this.onClearTelemetryPersistence,
    this.onClearLivePollHealth,
    required this.onClearProfilePersistence,
    this.onClearSavedViewsPersistence,
    required this.stressRunning,
    this.intakeStatus,
    this.stressStatus,
    this.intakeTelemetry,
    required this.events,
    required this.onExecute,
  });

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  static const _clipboard = DispatchClipboardService();
  static const _snapshotFiles = DispatchSnapshotFileService();
  static const _newsIntelSourceTypes = {'news', 'weather', 'community'};
  static const _intelFilterLabels = {
    'all': 'All',
    'community': 'Community',
    'news': 'News',
    'weather': 'Weather',
  };
  static const _intelActionFilterLabels = {
    'all': 'All Actions',
    'Dispatch Candidate': 'Dispatch Candidate',
    'Watch': 'Watch',
    'Advisory': 'Advisory',
  };
  static const _defaultHistoryStatuses = {
    'BASELINE',
    'IMPROVED',
    'STABLE',
    'DEGRADED',
  };
  static const _triagePolicy = IntelligenceTriagePolicy();
  static const int _maxDispatchQueueRows = 12;
  static const double _spaceXs = 6;
  static const double _spaceSm = 8;
  static const double _spaceMd = 10;
  static const double _spaceLg = 12;

  final Set<String> _expandedDispatchIds = <String>{};
  late final TextEditingController _scenarioLabelController;
  late final TextEditingController _scenarioTagsController;
  late final TextEditingController _runNoteController;
  late final TextEditingController _historyNoteFilterController;
  late IntakeStressProfile _profile;
  late List<DispatchBenchmarkFilterPreset> _savedFilterPresets;
  final Set<String> _pinnedWatchIntelligenceIds = <String>{};
  final Set<String> _dismissedIntelligenceIds = <String>{};
  bool _showCancelledRuns = true;
  int _historyLimit = 6;
  String? _baselineRunLabel;
  String? _historyScenarioFilter;
  String? _historyTagFilter;
  String? _activeFilterPresetName;
  late String _intelligenceSourceFilter;
  late String _intelligenceActionFilter;
  bool _showPinnedWatchIntelligenceOnly = false;
  bool _showDismissedIntelligenceOnly = false;
  String _selectedIntelligenceId = '';
  DispatchBenchmarkSort _historySort = DispatchBenchmarkSort.latest;
  final Set<String> _statusFilters = {..._defaultHistoryStatuses};

  @override
  void initState() {
    super.initState();
    _scenarioLabelController = TextEditingController(
      text: widget.initialScenarioLabel,
    );
    _scenarioTagsController = TextEditingController(
      text: widget.initialScenarioTags.join(', '),
    );
    _runNoteController = TextEditingController(text: widget.initialRunNote);
    _historyNoteFilterController = TextEditingController();
    _profile = widget.initialProfile;
    _savedFilterPresets = List<DispatchBenchmarkFilterPreset>.from(
      widget.initialFilterPresets,
    );
    _intelligenceSourceFilter = widget.initialIntelligenceSourceFilter;
    _intelligenceActionFilter = widget.initialIntelligenceActionFilter;
    _showPinnedWatchIntelligenceOnly =
        widget.initialShowPinnedWatchIntelligenceOnly;
    _showDismissedIntelligenceOnly =
        widget.initialShowDismissedIntelligenceOnly;
    _selectedIntelligenceId = widget.initialSelectedIntelligenceId;
    _pinnedWatchIntelligenceIds.addAll(
      widget.initialPinnedWatchIntelligenceIds,
    );
    _dismissedIntelligenceIds.addAll(widget.initialDismissedIntelligenceIds);
  }

  @override
  void dispose() {
    _scenarioLabelController.dispose();
    _scenarioTagsController.dispose();
    _runNoteController.dispose();
    _historyNoteFilterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DispatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProfile != oldWidget.initialProfile &&
        widget.initialProfile != _profile) {
      _profile = widget.initialProfile;
    }
    if (widget.initialScenarioLabel != oldWidget.initialScenarioLabel &&
        widget.initialScenarioLabel != _scenarioLabelController.text) {
      _scenarioLabelController.text = widget.initialScenarioLabel;
    }
    final nextTags = widget.initialScenarioTags.join(', ');
    final prevTags = oldWidget.initialScenarioTags.join(', ');
    if (nextTags != prevTags && nextTags != _scenarioTagsController.text) {
      _scenarioTagsController.text = nextTags;
    }
    if (widget.initialRunNote != oldWidget.initialRunNote &&
        widget.initialRunNote != _runNoteController.text) {
      _runNoteController.text = widget.initialRunNote;
    }
    if (widget.initialFilterPresets != oldWidget.initialFilterPresets) {
      _savedFilterPresets = List<DispatchBenchmarkFilterPreset>.from(
        widget.initialFilterPresets,
      );
      if (_activeFilterPresetName != null &&
          !_savedFilterPresets.any(
            (preset) => preset.name == _activeFilterPresetName,
          )) {
        _activeFilterPresetName = null;
      }
    }
    if (widget.initialIntelligenceSourceFilter !=
            oldWidget.initialIntelligenceSourceFilter &&
        widget.initialIntelligenceSourceFilter != _intelligenceSourceFilter) {
      _intelligenceSourceFilter = widget.initialIntelligenceSourceFilter;
    }
    if (widget.initialIntelligenceActionFilter !=
            oldWidget.initialIntelligenceActionFilter &&
        widget.initialIntelligenceActionFilter != _intelligenceActionFilter) {
      _intelligenceActionFilter = widget.initialIntelligenceActionFilter;
    }
    if (widget.initialShowPinnedWatchIntelligenceOnly !=
        oldWidget.initialShowPinnedWatchIntelligenceOnly) {
      _showPinnedWatchIntelligenceOnly =
          widget.initialShowPinnedWatchIntelligenceOnly;
    }
    if (widget.initialShowDismissedIntelligenceOnly !=
        oldWidget.initialShowDismissedIntelligenceOnly) {
      _showDismissedIntelligenceOnly =
          widget.initialShowDismissedIntelligenceOnly;
    }
    if (widget.initialSelectedIntelligenceId !=
            oldWidget.initialSelectedIntelligenceId &&
        widget.initialSelectedIntelligenceId != _selectedIntelligenceId) {
      _selectedIntelligenceId = widget.initialSelectedIntelligenceId;
    }
    if (widget.initialPinnedWatchIntelligenceIds !=
        oldWidget.initialPinnedWatchIntelligenceIds) {
      _pinnedWatchIntelligenceIds
        ..clear()
        ..addAll(widget.initialPinnedWatchIntelligenceIds);
    }
    if (widget.initialDismissedIntelligenceIds !=
        oldWidget.initialDismissedIntelligenceIds) {
      _dismissedIntelligenceIds
        ..clear()
        ..addAll(widget.initialDismissedIntelligenceIds);
    }
  }

  void _updateProfile(IntakeStressProfile profile) {
    setState(() => _profile = profile);
    widget.onProfileChanged(profile);
  }

  void _notifyScenarioChanged() {
    widget.onScenarioChanged(
      _scenarioLabelController.text.trim(),
      _snapshotTags,
    );
  }

  void _notifyRunNoteChanged() {
    widget.onRunNoteChanged(_runNoteController.text.trim());
  }

  void _clearHistoryFilters() {
    setState(() {
      _showCancelledRuns = true;
      _statusFilters
        ..clear()
        ..addAll(_defaultHistoryStatuses);
      _historyScenarioFilter = null;
      _historyTagFilter = null;
      _baselineRunLabel = null;
      _activeFilterPresetName = null;
      _historyNoteFilterController.clear();
    });
  }

  void _updateViewState(VoidCallback action) {
    setState(action);
  }

  void _setIntelligenceFilters({String? sourceFilter, String? actionFilter}) {
    final nextSource = sourceFilter ?? _intelligenceSourceFilter;
    final nextAction = actionFilter ?? _intelligenceActionFilter;
    if (nextSource == _intelligenceSourceFilter &&
        nextAction == _intelligenceActionFilter) {
      return;
    }
    setState(() {
      _intelligenceSourceFilter = nextSource;
      _intelligenceActionFilter = nextAction;
    });
    widget.onIntelligenceFiltersChanged?.call(nextSource, nextAction);
  }

  void _persistIntelligenceTriage() {
    widget.onIntelligenceTriageChanged?.call(
      _pinnedWatchIntelligenceIds.toList(growable: false),
      _dismissedIntelligenceIds.toList(growable: false),
    );
  }

  void _persistIntelligenceViewModes() {
    widget.onIntelligenceViewModesChanged?.call(
      _showPinnedWatchIntelligenceOnly,
      _showDismissedIntelligenceOnly,
    );
  }

  void _selectIntelligence(String intelligenceId) {
    if (_selectedIntelligenceId == intelligenceId) {
      return;
    }
    setState(() {
      _selectedIntelligenceId = intelligenceId;
    });
    widget.onSelectedIntelligenceChanged?.call(intelligenceId);
  }

  void _setDismissedIntelligenceView(bool enabled) {
    if (_showDismissedIntelligenceOnly == enabled) {
      return;
    }
    setState(() {
      _showDismissedIntelligenceOnly = enabled;
      if (enabled) {
        _showPinnedWatchIntelligenceOnly = false;
      }
    });
    _persistIntelligenceViewModes();
  }

  void _setPinnedWatchIntelligenceView(bool enabled) {
    if (_showPinnedWatchIntelligenceOnly == enabled) {
      return;
    }
    setState(() {
      _showPinnedWatchIntelligenceOnly = enabled;
      if (enabled) {
        _showDismissedIntelligenceOnly = false;
      }
    });
    _persistIntelligenceViewModes();
  }

  Future<void> _showNewsSourceDiagnostics({bool configuredOnly = false}) async {
    final displayedDiagnostics = configuredOnly
        ? widget.newsSourceDiagnostics
              .where(
                (diagnostic) =>
                    widget.configuredNewsSources.contains(diagnostic.provider),
              )
              .toList(growable: false)
        : widget.newsSourceDiagnostics;
    final dialogTitle = configuredOnly
        ? 'Configured News Sources'
        : 'News Source Diagnostics';
    final diagnosticsScopeLabel = configuredOnly
        ? 'Showing: configured providers only (${displayedDiagnostics.length})'
        : 'Showing: all providers (${displayedDiagnostics.length})';
    final reachableCount = displayedDiagnostics
        .where((diagnostic) => diagnostic.status.startsWith('reachable'))
        .length;
    final staleCount = displayedDiagnostics
        .where(_isStaleNewsDiagnostic)
        .length;
    final missingCount = displayedDiagnostics
        .where((diagnostic) => diagnostic.status.startsWith('missing'))
        .length;
    var diagnosticsFilter = 'all';
    String? selectedDiagnosticProvider;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final diagnosticsFilterLabel = switch (diagnosticsFilter) {
              'reachable' => 'Filter: Reachable',
              'stale' => 'Filter: Stale',
              'missing' => 'Filter: Missing',
              _ => 'Filter: All',
            };
            final filteredDiagnostics = displayedDiagnostics
                .where((diagnostic) {
                  switch (diagnosticsFilter) {
                    case 'reachable':
                      return diagnostic.status.startsWith('reachable');
                    case 'stale':
                      return _isStaleNewsDiagnostic(diagnostic);
                    case 'missing':
                      return diagnostic.status.startsWith('missing');
                    default:
                      return true;
                  }
                })
                .toList(growable: false);
            if (selectedDiagnosticProvider != null &&
                !filteredDiagnostics.any(
                  (entry) => entry.provider == selectedDiagnosticProvider,
                )) {
              selectedDiagnosticProvider = null;
            }
            final selectedDiagnostic = filteredDiagnostics.isEmpty
                ? null
                : filteredDiagnostics.firstWhere(
                    (entry) =>
                        entry.provider ==
                        (selectedDiagnosticProvider ??
                            filteredDiagnostics.first.provider),
                    orElse: () => filteredDiagnostics.first,
                  );
            selectedDiagnosticProvider = selectedDiagnostic?.provider;
            final diagnosticsChecklist = _formatNewsSourceDiagnosticsChecklist(
              filteredDiagnostics,
            );
            final configuredProbeableDiagnostics = filteredDiagnostics
                .where(
                  (diagnostic) =>
                      widget.configuredNewsSources.contains(
                        diagnostic.provider,
                      ) &&
                      _canProbeNewsDiagnostic(diagnostic.status),
                )
                .toList(growable: false);
            final staleProbeableDiagnostics = filteredDiagnostics
                .where(
                  (diagnostic) =>
                      _isStaleNewsDiagnostic(diagnostic) &&
                      _canProbeNewsDiagnostic(diagnostic.status),
                )
                .toList(growable: false);
            final probeableDiagnosticsCount = filteredDiagnostics
                .where(
                  (diagnostic) => _canProbeNewsDiagnostic(diagnostic.status),
                )
                .length;
            return AlertDialog(
              backgroundColor: const Color(0xFF0A1830),
              title: Text(
                dialogTitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5F1FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagnosticsScopeLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7FB0DE),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnosticsFilterLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9FB6D5),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (diagnosticsFilter != 'all') ...[
                      const SizedBox(height: 2),
                      TextButton(
                        onPressed: () =>
                            setState(() => diagnosticsFilter = 'all'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Reset Filter',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8FD1FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildNewsDiagnosticsFilterChip(
                          label: 'All: ${displayedDiagnostics.length}',
                          selected: diagnosticsFilter == 'all',
                          enabled: true,
                          onTap: () =>
                              setState(() => diagnosticsFilter = 'all'),
                        ),
                        _buildNewsDiagnosticsFilterChip(
                          label: 'Reachable: $reachableCount',
                          selected: diagnosticsFilter == 'reachable',
                          enabled: reachableCount > 0,
                          onTap: () =>
                              setState(() => diagnosticsFilter = 'reachable'),
                        ),
                        _buildNewsDiagnosticsFilterChip(
                          label: 'Stale: $staleCount',
                          selected: diagnosticsFilter == 'stale',
                          enabled: staleCount > 0,
                          onTap: () =>
                              setState(() => diagnosticsFilter = 'stale'),
                        ),
                        _buildNewsDiagnosticsFilterChip(
                          label: 'Missing: $missingCount',
                          selected: diagnosticsFilter == 'missing',
                          enabled: missingCount > 0,
                          onTap: () =>
                              setState(() => diagnosticsFilter = 'missing'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...filteredDiagnostics.isEmpty
                        ? [
                            Text(
                              displayedDiagnostics.isEmpty
                                  ? configuredOnly
                                        ? 'No configured news sources are available in this build.'
                                        : 'No news source diagnostics are available.'
                                  : 'No providers match the current filter.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9FB6D5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]
                        : filteredDiagnostics
                              .map((diagnostic) {
                                final selected =
                                    selectedDiagnostic?.provider ==
                                    diagnostic.provider;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () => setState(
                                      () => selectedDiagnosticProvider =
                                          diagnostic.provider,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF102B4B)
                                            : const Color(0xFF07162A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF7FCBFF)
                                              : const Color(0xFF1E3D62),
                                        ),
                                      ),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${diagnostic.provider}: ${diagnostic.status}',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFE5F1FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_isStaleNewsDiagnostic(
                                            diagnostic,
                                          ))
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3A2414),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFD6A5,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                'Stale',
                                                style: GoogleFonts.inter(
                                                  color: const Color(
                                                    0xFFFFD6A5,
                                                  ),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(growable: false),
                    if (selectedDiagnostic != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF081A2F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF25486D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diagnostics Drilldown',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8FD1FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              'Provider: ${selectedDiagnostic.provider}\n'
                              'Status: ${selectedDiagnostic.status}\n'
                              'Status Class: ${_newsDiagnosticStatusClass(selectedDiagnostic)}\n'
                              'Configured Source: ${widget.configuredNewsSources.contains(selectedDiagnostic.provider) ? 'yes' : 'no'}\n'
                              'Probeable: ${_canProbeNewsDiagnostic(selectedDiagnostic.status) ? 'yes' : 'no'}\n'
                              'Stale: ${_isStaleNewsDiagnostic(selectedDiagnostic) ? 'yes' : 'no'}\n'
                              'Last Checked: ${selectedDiagnostic.checkedAtUtc.trim().isEmpty ? 'n/a' : selectedDiagnostic.checkedAtUtc}\n'
                              'Failure Trace: ${_newsDiagnosticFailureTrace(selectedDiagnostic)}\n'
                              'Detail: ${selectedDiagnostic.detail}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFC2D8F2),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.onProbeNewsSource != null) ...[
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed:
                                    _canProbeNewsDiagnostic(
                                      selectedDiagnostic.status,
                                    )
                                    ? () {
                                        Navigator.of(context).pop();
                                        widget.onProbeNewsSource!(
                                          selectedDiagnostic.provider,
                                        );
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _canProbeNewsDiagnostic(
                                        selectedDiagnostic.status,
                                      )
                                      ? 'Run Probe'
                                      : 'Run Probe (Unavailable)',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF8FD1FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (widget.onProbeNewsSource != null &&
                        filteredDiagnostics.isNotEmpty &&
                        probeableDiagnosticsCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$probeableDiagnosticsCount probeable provider${probeableDiagnosticsCount == 1 ? '' : 's'} in the current filter.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9FD8AC),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (widget.onProbeNewsSource != null &&
                        filteredDiagnostics.isNotEmpty &&
                        configuredProbeableDiagnostics.isEmpty &&
                        staleProbeableDiagnostics.isEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'No probeable providers in the current filter.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD6A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (filteredDiagnostics.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${filteredDiagnostics.length} row${filteredDiagnostics.length == 1 ? '' : 's'} available to copy in the current filter.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9FD8AC),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'No rows available to copy in the current filter.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD6A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (widget.onProbeNewsSource != null)
                  TextButton(
                    onPressed: configuredProbeableDiagnostics.isEmpty
                        ? null
                        : () {
                            final providers = configuredProbeableDiagnostics
                                .map((diagnostic) => diagnostic.provider)
                                .toList(growable: false);
                            Navigator.of(context).pop();
                            for (final provider in providers) {
                              widget.onProbeNewsSource!(provider);
                            }
                          },
                    child: Text(
                      configuredProbeableDiagnostics.isEmpty
                          ? 'Reprobe All Configured (Unavailable: 0)'
                          : 'Reprobe All Configured (${configuredProbeableDiagnostics.length})',
                      style: GoogleFonts.inter(color: const Color(0xFF8FD1FF)),
                    ),
                  ),
                if (widget.onProbeNewsSource != null)
                  TextButton(
                    onPressed: staleProbeableDiagnostics.isEmpty
                        ? null
                        : () {
                            final providers = staleProbeableDiagnostics
                                .map((diagnostic) => diagnostic.provider)
                                .toList(growable: false);
                            Navigator.of(context).pop();
                            for (final provider in providers) {
                              widget.onProbeNewsSource!(provider);
                            }
                          },
                    child: Text(
                      staleProbeableDiagnostics.isEmpty
                          ? 'Reprobe Stale (Unavailable: 0)'
                          : 'Reprobe Stale (${staleProbeableDiagnostics.length})',
                      style: GoogleFonts.inter(color: const Color(0xFF8FD1FF)),
                    ),
                  ),
                TextButton(
                  onPressed: filteredDiagnostics.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: diagnosticsChecklist),
                          );
                          if (!mounted) return;
                          _showSnack('News diagnostics copied');
                        },
                  child: Text(
                    'Copy Checklist (${filteredDiagnostics.length})',
                    style: GoogleFonts.inter(color: const Color(0xFF9FD8AC)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(color: const Color(0xFF8FD1FF)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNewsDiagnosticsFilterChip({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: !enabled
            ? const Color(0xFF5D708B)
            : selected
            ? const Color(0xFF0A1830)
            : const Color(0xFF9FB6D5),
        backgroundColor: !enabled
            ? const Color(0x081A2E4A)
            : selected
            ? const Color(0xFF8FD1FF)
            : const Color(0x142A5E97),
        side: BorderSide(
          color: !enabled
              ? const Color(0xFF24364F)
              : selected
              ? const Color(0xFF8FD1FF)
              : const Color(0xFF2A5E97),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatNewsSourceDiagnosticsChecklist(
    List<NewsSourceDiagnostic> diagnostics,
  ) {
    return diagnostics
        .map(
          (diagnostic) =>
              '${diagnostic.provider}: ${diagnostic.status}\n${diagnostic.detail}',
        )
        .join('\n\n');
  }

  String _newsDiagnosticStatusClass(NewsSourceDiagnostic diagnostic) {
    if (diagnostic.status.startsWith('missing')) {
      return 'missing';
    }
    if (_isStaleNewsDiagnostic(diagnostic)) {
      return 'stale';
    }
    if (diagnostic.status == 'probe failed') {
      return 'failed';
    }
    if (diagnostic.status.startsWith('reachable')) {
      return 'reachable';
    }
    if (diagnostic.status == 'configured') {
      return 'configured';
    }
    return 'other';
  }

  String _newsDiagnosticFailureTrace(NewsSourceDiagnostic diagnostic) {
    if (diagnostic.status.startsWith('missing')) {
      return 'configuration missing';
    }
    if (diagnostic.status == 'probe failed') {
      return diagnostic.detail;
    }
    if (_isStaleNewsDiagnostic(diagnostic)) {
      return 'stale probe result (older than 15 minutes)';
    }
    return 'none';
  }

  String get _newsSourceHealthSummary {
    final reachableCount = widget.newsSourceDiagnostics
        .where((diagnostic) => diagnostic.status.startsWith('reachable'))
        .length;
    final configuredCount = widget.newsSourceDiagnostics
        .where((diagnostic) => diagnostic.status == 'configured')
        .length;
    final failedCount = widget.newsSourceDiagnostics
        .where((diagnostic) => diagnostic.status == 'probe failed')
        .length;
    final staleCount = widget.newsSourceDiagnostics
        .where(_isStaleNewsDiagnostic)
        .length;
    final missingCount = widget.newsSourceDiagnostics
        .where((diagnostic) => diagnostic.status.startsWith('missing'))
        .length;
    return '$reachableCount reachable / $configuredCount configured / '
        '$failedCount failed / $staleCount stale / $missingCount missing';
  }

  bool _canProbeNewsDiagnostic(String status) {
    return !status.startsWith('missing') && status != 'unsupported';
  }

  bool _isStaleNewsDiagnostic(NewsSourceDiagnostic diagnostic) {
    final raw = diagnostic.checkedAtUtc.trim();
    if (raw.isEmpty) {
      return false;
    }
    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(parsed) >
        const Duration(minutes: 15);
  }

  @override
  Widget build(BuildContext context) {
    final decisions = widget.events.whereType<DecisionCreated>().where((d) {
      return d.clientId == widget.clientId &&
          d.regionId == widget.regionId &&
          d.siteId == widget.siteId;
    }).toList()..sort((a, b) => b.sequence.compareTo(a.sequence));

    final executions = widget.events.whereType<ExecutionCompleted>().where((e) {
      return e.clientId == widget.clientId &&
          e.regionId == widget.regionId &&
          e.siteId == widget.siteId;
    }).toList();

    final denied = widget.events.whereType<ExecutionDenied>().where((e) {
      return e.clientId == widget.clientId &&
          e.regionId == widget.regionId &&
          e.siteId == widget.siteId;
    }).toList();

    final responses = widget.events.whereType<ResponseArrived>().where((e) {
      return e.clientId == widget.clientId &&
          e.regionId == widget.regionId &&
          e.siteId == widget.siteId;
    }).toList();

    final closures = widget.events.whereType<IncidentClosed>().where((e) {
      return e.clientId == widget.clientId &&
          e.regionId == widget.regionId &&
          e.siteId == widget.siteId;
    }).toList();
    final siteIntel = widget.events.whereType<IntelligenceReceived>().where((
      e,
    ) {
      return e.clientId == widget.clientId &&
          e.regionId == widget.regionId &&
          e.siteId == widget.siteId &&
          !_dismissedIntelligenceIds.contains(e.intelligenceId);
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recentNewsIntel = siteIntel
        .where((e) => _newsIntelSourceTypes.contains(e.sourceType))
        .toList(growable: false);

    final executionByDispatch = {for (final e in executions) e.dispatchId: e};
    final deniedByDispatch = {for (final d in denied) d.dispatchId: d};
    final responsesByDispatch = <String, List<ResponseArrived>>{};
    for (final response in responses) {
      responsesByDispatch
          .putIfAbsent(response.dispatchId, () => [])
          .add(response);
    }
    final closureByDispatch = {for (final c in closures) c.dispatchId: c};
    final compactDensity = MediaQuery.sizeOf(context).width < 1460;

    return Scaffold(
      backgroundColor: const Color(0xFF040A16),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF071223), Color(0xFF040A16)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(_spaceLg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Column(
                  children: [
                    _dispatchHeroCard(
                      decisions: decisions,
                      executions: executions,
                      denied: denied,
                      compact: compactDensity,
                    ),
                    const SizedBox(height: _spaceMd),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useTwoColumn = constraints.maxWidth >= 1240;
                        final compactDensity = constraints.maxWidth < 1460;
                        final sectionGap = compactDensity ? _spaceSm : _spaceMd;
                        final systemStatusCard = _dispatchShellCard(
                          title: 'System Status',
                          subtitle:
                              'Feed readiness, news-source diagnostics, poll state, and live ingest messaging are grouped here instead of floating between control rows.',
                          compact: compactDensity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _operationalWiringBlock(),
                              SizedBox(
                                height: compactDensity ? _spaceSm : _spaceMd,
                              ),
                              _newsAndFeedStatusBlock(),
                              SizedBox(
                                height: compactDensity ? _spaceSm : _spaceMd,
                              ),
                              _triagePostureBlock(
                                allIntel: siteIntel,
                                decisions: decisions,
                              ),
                              if (widget.intakeStatus != null) ...[
                                SizedBox(
                                  height: compactDensity ? _spaceSm : _spaceMd,
                                ),
                                _dispatchStatusLine(
                                  widget.intakeStatus!,
                                  const Color(0xFF7FB0DE),
                                ),
                              ],
                              if (widget.runtimeConfigHint != null) ...[
                                SizedBox(
                                  height: compactDensity ? _spaceXs : _spaceSm,
                                ),
                                _dispatchStatusLine(
                                  widget.runtimeConfigHint!,
                                  const Color(0xFFFFD6A5),
                                ),
                              ],
                              if (widget.livePollingLabel != null) ...[
                                SizedBox(
                                  height: compactDensity ? _spaceXs : _spaceSm,
                                ),
                                _dispatchStatusLine(
                                  widget.livePollingLabel!,
                                  const Color(0xFF9FD8AC),
                                ),
                              ],
                              if (widget.livePollingHistory.isNotEmpty) ...[
                                SizedBox(
                                  height: compactDensity ? _spaceSm : _spaceMd,
                                ),
                                _livePollingHistoryCard(
                                  widget.livePollingHistory,
                                ),
                              ],
                            ],
                          ),
                        );
                        final intelligenceCard = recentNewsIntel.isEmpty
                            ? null
                            : _dispatchShellCard(
                                title: 'Intelligence Review',
                                subtitle:
                                    'High-signal news and community intelligence stays in its own review block rather than competing with the control workspace.',
                                compact: compactDensity,
                                child: _intelligenceBriefingCard(
                                  recentNewsIntel,
                                  allIntel: siteIntel,
                                  decisions: decisions,
                                ),
                              );
                        final telemetryCard = widget.intakeTelemetry == null
                            ? null
                            : _dispatchShellCard(
                                title: 'Telemetry & History',
                                subtitle:
                                    'Performance metrics, ingest history, and benchmark traces are grouped into a dedicated review section.',
                                compact: compactDensity,
                                child: Column(
                                  children: [
                                    _telemetryCard(widget.intakeTelemetry!),
                                    _liveIngestHistory(widget.intakeTelemetry!),
                                    _benchmarkHistory(widget.intakeTelemetry!),
                                  ],
                                ),
                              );
                        final controlCard = _dispatchShellCard(
                          title: 'Control Workspace',
                          subtitle:
                              'Scenario setup, stress controls, imports, exports, and snapshot tools remain intact but sit inside one clear command zone.',
                          compact: compactDensity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _stressControlCard(),
                              if (widget.stressStatus != null) ...[
                                SizedBox(height: compactDensity ? 8 : 10),
                                _dispatchStatusLine(
                                  widget.stressStatus!,
                                  const Color(0xFF9FD8AC),
                                ),
                              ],
                            ],
                          ),
                        );
                        final queueCard = _dispatchQueueCard(
                          decisions: decisions,
                          executionByDispatch: executionByDispatch,
                          deniedByDispatch: deniedByDispatch,
                          responsesByDispatch: responsesByDispatch,
                          closureByDispatch: closureByDispatch,
                        );

                        if (!useTwoColumn) {
                          return Column(
                            children: [
                              systemStatusCard,
                              if (intelligenceCard != null) ...[
                                SizedBox(height: sectionGap),
                                intelligenceCard,
                              ],
                              SizedBox(height: sectionGap),
                              controlCard,
                              if (telemetryCard != null) ...[
                                SizedBox(height: sectionGap),
                                telemetryCard,
                              ],
                              SizedBox(height: sectionGap),
                              queueCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 9,
                              child: Column(
                                children: [
                                  controlCard,
                                  SizedBox(height: sectionGap),
                                  queueCard,
                                ],
                              ),
                            ),
                            SizedBox(width: sectionGap),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  systemStatusCard,
                                  if (intelligenceCard != null) ...[
                                    SizedBox(height: sectionGap),
                                    intelligenceCard,
                                  ],
                                  if (telemetryCard != null) ...[
                                    SizedBox(height: sectionGap),
                                    telemetryCard,
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _dispatchHeroCard({
    required List<DecisionCreated> decisions,
    required List<ExecutionCompleted> executions,
    required List<ExecutionDenied> denied,
    bool compact = false,
  }) {
    return _dispatchShellCard(
      title:
          'Dispatch Command — ${widget.clientId} / ${widget.regionId} / ${widget.siteId}',
      subtitle:
          'Primary command surface for dispatch creation, feed ingest, and operational review. The top band now separates posture, command actions, and transport controls from the heavier workspace below.',
      compact: compact,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 1080;
          final summaryPanel = Container(
            padding: EdgeInsets.all(compact ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF09172B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF17355B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operational Posture',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: _heroStatTile(
                        label: 'Decisions',
                        value: decisions.length.toString(),
                        accent: const Color(0xFF56B6FF),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: _heroStatTile(
                        label: 'Executed',
                        value: executions.length.toString(),
                        accent: const Color(0xFF4ED4A3),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: _heroStatTile(
                        label: 'Denied',
                        value: denied.length.toString(),
                        accent: const Color(0xFFFFB44D),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                Text(
                  widget.livePolling
                      ? 'Live feed polling is active. Command transport is monitoring for new intake now.'
                      : 'Command transport is idle. Use live ingest or file-based intake to refresh the queue.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB7C8E0),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
          final actionsPanel = Container(
            padding: EdgeInsets.all(compact ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF09172B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF17355B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Command Actions',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onGenerate,
                        style: _heroPrimaryButtonStyle(),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          'Generate Dispatch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Text(
                  'Transport & Intake',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6F8FB6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onIngestFeeds,
                      style: _heroOutlinedButtonStyle(
                        foregroundColor: const Color(0xFF8FD1FF),
                        sideColor: const Color(0xFF2A5E97),
                      ),
                      icon: const Icon(Icons.stream_rounded),
                      label: Text(
                        'Ingest Live Feeds',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.onIngestNews != null)
                      OutlinedButton.icon(
                        onPressed: widget.onIngestNews,
                        style: _heroOutlinedButtonStyle(
                          foregroundColor: const Color(0xFFFFE7B5),
                          sideColor: const Color(0xFF8A6B2D),
                        ),
                        icon: const Icon(Icons.newspaper_rounded),
                        label: Text(
                          'Ingest News Intel',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (widget.onLoadFeedFile != null)
                      OutlinedButton.icon(
                        onPressed: widget.onLoadFeedFile,
                        style: _heroOutlinedButtonStyle(
                          foregroundColor: const Color(0xFF8FD1FF),
                          sideColor: const Color(0xFF2A5E97),
                        ),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(
                          'Load Feed File',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (widget.livePolling
                        ? widget.onStopLivePolling != null
                        : widget.onStartLivePolling != null)
                      OutlinedButton.icon(
                        onPressed: widget.livePolling
                            ? widget.onStopLivePolling
                            : widget.onStartLivePolling,
                        style: _heroOutlinedButtonStyle(
                          foregroundColor: widget.livePolling
                              ? const Color(0xFFFFD3D8)
                              : const Color(0xFFCFF1DB),
                          sideColor: widget.livePolling
                              ? const Color(0xFF8A3D4A)
                              : const Color(0xFF3E7B58),
                        ),
                        icon: Icon(
                          widget.livePolling
                              ? Icons.pause_circle_outline_rounded
                              : Icons.sync_rounded,
                        ),
                        label: Text(
                          widget.livePolling
                              ? 'Stop Feed Polling'
                              : 'Start Feed Polling',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summaryPanel,
                SizedBox(height: compact ? 10 : 12),
                actionsPanel,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: summaryPanel),
              SizedBox(width: compact ? 10 : 12),
              Expanded(flex: 7, child: actionsPanel),
            ],
          );
        },
      ),
    );
  }

  ButtonStyle _heroPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A4F89),
      foregroundColor: const Color(0xFFE5F2FF),
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _heroOutlinedButtonStyle({
    required Color foregroundColor,
    required Color sideColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      side: BorderSide(color: sideColor),
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _dispatchShellCard({
    required String title,
    required String subtitle,
    required Widget child,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF081326), Color(0xFF09162A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: const Color(0xFF163252)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE6F1FF),
              fontSize: compact ? 21 : 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 3 : 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          child,
        ],
      ),
    );
  }

  Widget _newsAndFeedStatusBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onIngestNews != null) ...[
          if (widget.configuredNewsSources.isEmpty)
            _statusBoardTile(
              text: 'News Sources Detected: none',
              color: const Color(0xFFFFD6A5),
            )
          else
            _statusBoardTile(
              text:
                  'News Sources Detected: ${widget.configuredNewsSources.join(', ')}',
              color: const Color(0xFF9FD8AC),
              onTap: () => _showNewsSourceDiagnostics(configuredOnly: true),
            ),
          if (widget.newsSourceDiagnostics.isNotEmpty) ...[
            const SizedBox(height: 4),
            _statusBoardTile(
              text: 'Provider Health: $_newsSourceHealthSummary',
              color: const Color(0xFF7FB0DE),
              onTap: _showNewsSourceDiagnostics,
            ),
          ],
          if (widget.newsSourceRequirementsHint != null) ...[
            const SizedBox(height: 4),
            _statusBoardTile(
              text: 'Missing Config: ${widget.newsSourceRequirementsHint!}',
              color: const Color(0xFFFFD6A5),
            ),
          ],
          const SizedBox(height: 4),
          _statusBoardTile(
            text: 'News Source Diagnostics',
            color: const Color(0xFF8FD1FF),
            onTap: _showNewsSourceDiagnostics,
          ),
        ] else
          _statusBoardTile(
            text:
                'Live feed ingest is active. News-source diagnostics appear here when news ingest is enabled.',
            color: const Color(0xFF8EA4C2),
          ),
      ],
    );
  }

  Widget _operationalWiringBlock() {
    final supabaseLabel = widget.supabaseReady
        ? 'SUPABASE: LIVE'
        : 'SUPABASE: IN-MEMORY';
    final supabaseColor = widget.supabaseReady
        ? const Color(0xFF9FD8AC)
        : const Color(0xFFFFA8B4);
    final syncLabel = widget.guardSyncBackendEnabled
        ? 'GUARD SYNC: BACKEND'
        : 'GUARD SYNC: LOCAL FALLBACK';
    final syncColor = widget.guardSyncBackendEnabled
        ? const Color(0xFF8FD1FF)
        : const Color(0xFFFFD6A5);
    final telemetryModeLabel = widget.telemetryAdapterStubMode
        ? 'TELEMETRY: STUB'
        : 'TELEMETRY: LIVE';
    final telemetryModeColor = widget.telemetryAdapterStubMode
        ? const Color(0xFFFFD6A5)
        : const Color(0xFF9FD8AC);
    final telemetryGateLabel = !widget.telemetryLiveReadyGateEnabled
        ? 'GATE: DISABLED'
        : widget.telemetryLiveReadyGateViolation
        ? 'GATE: VIOLATION'
        : 'GATE: OK';
    final telemetryGateColor = !widget.telemetryLiveReadyGateEnabled
        ? const Color(0xFFFFD6A5)
        : widget.telemetryLiveReadyGateViolation
        ? const Color(0xFFFFA8B4)
        : const Color(0xFF9FD8AC);
    final telemetryProviderSummary =
        'Telemetry provider: ${widget.telemetryProviderActiveId ?? 'unknown'} / ${widget.telemetryProviderExpectedId} • readiness: ${widget.telemetryProviderReadiness}';
    final gateReason = widget.telemetryLiveReadyGateReason?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusBadge(supabaseLabel, supabaseColor),
            _statusBadge(syncLabel, syncColor),
            _statusBadge(telemetryModeLabel, telemetryModeColor),
            _statusBadge(telemetryGateLabel, telemetryGateColor),
          ],
        ),
        const SizedBox(height: 8),
        _statusBoardTile(
          text: telemetryProviderSummary,
          color: const Color(0xFF8FD1FF),
        ),
        if (gateReason != null && gateReason.isNotEmpty) ...[
          const SizedBox(height: 4),
          _statusBoardTile(
            text: 'Telemetry gate reason: $gateReason',
            color: telemetryGateColor,
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _statusBoardTile({
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1A2F), Color(0xFF091628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B395F)),
      ),
      child: onTap == null
          ? content
          : TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: content,
            ),
    );
  }

  Widget _dispatchStatusLine(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A355A)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _triagePostureBlock({
    required List<IntelligenceReceived> allIntel,
    required List<DecisionCreated> decisions,
  }) {
    if (allIntel.isEmpty) {
      return _statusBoardTile(
        text: 'Triage Posture: no active intelligence for this site.',
        color: const Color(0xFF8EA4C2),
      );
    }

    var advisoryCount = 0;
    var watchCount = 0;
    var dispatchCandidateCount = 0;
    var autoEscalateCount = 0;
    final rationaleCounts = <String, int>{};

    for (final item in allIntel) {
      final assessment = _intelligenceAssessment(
        item,
        allIntel: allIntel,
        decisions: decisions,
      );
      switch (assessment.recommendation) {
        case IntelligenceRecommendation.advisory:
          advisoryCount += 1;
          break;
        case IntelligenceRecommendation.watch:
          watchCount += 1;
          break;
        case IntelligenceRecommendation.dispatchCandidate:
          dispatchCandidateCount += 1;
          break;
      }
      if (assessment.shouldEscalate) {
        autoEscalateCount += 1;
      }
      for (final reason in assessment.rationale) {
        final key = reason.split(':').first.trim();
        if (key.isEmpty || key == 'recommendation') {
          continue;
        }
        rationaleCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final topSignals = rationaleCounts.entries.toList(growable: false)
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        if (byCount != 0) {
          return byCount;
        }
        return left.key.compareTo(right.key);
      });
    final signalSummary = topSignals.isEmpty
        ? 'none'
        : topSignals
              .take(3)
              .map((entry) => '${entry.key} ${entry.value}')
              .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusBoardTile(
          text:
              'Triage Posture: A $advisoryCount • W $watchCount • DC $dispatchCandidateCount • Escalate $autoEscalateCount',
          color: autoEscalateCount > 0
              ? const Color(0xFFFFD6A5)
              : const Color(0xFF8FD1FF),
        ),
        const SizedBox(height: 4),
        _statusBoardTile(
          text: 'Top Triage Signals: $signalSummary',
          color: const Color(0xFFAFCAE9),
        ),
      ],
    );
  }

  Widget _dispatchQueueCard({
    required List<DecisionCreated> decisions,
    required Map<String, ExecutionCompleted> executionByDispatch,
    required Map<String, ExecutionDenied> deniedByDispatch,
    required Map<String, List<ResponseArrived>> responsesByDispatch,
    required Map<String, IncidentClosed> closureByDispatch,
  }) {
    final visibleDecisions = decisions
        .take(_maxDispatchQueueRows)
        .toList(growable: false);
    final hiddenDecisions = decisions.length - visibleDecisions.length;
    return _dispatchShellCard(
      title: 'Active Dispatch Queue',
      subtitle:
          'Decision cards are isolated in their own queue so execution status and drill-down details no longer compete with ingest and telemetry controls.',
      child: decisions.isEmpty
          ? Text(
              'No dispatch decisions are currently available for this site.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleDecisions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = visibleDecisions[index];
                    final executed = executionByDispatch[d.dispatchId];
                    final deniedEvt = deniedByDispatch[d.dispatchId];
                    final dispatchResponses =
                        responsesByDispatch[d.dispatchId] ??
                        const <ResponseArrived>[];
                    final closure = closureByDispatch[d.dispatchId];
                    final isExecuted = executed != null;
                    final isDenied = deniedEvt != null;
                    final isExpanded = _expandedDispatchIds.contains(
                      d.dispatchId,
                    );

                    final status = isExecuted
                        ? (executed.success ? 'EXECUTED' : 'FAILED')
                        : isDenied
                        ? 'DENIED'
                        : 'DECIDED';
                    final statusColor = switch (status) {
                      'EXECUTED' => const Color(0xFF4ED4A3),
                      'FAILED' => const Color(0xFFFF6676),
                      'DENIED' => const Color(0xFFFFB44D),
                      _ => const Color(0xFF6CC5FF),
                    };

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D1B30), Color(0xFF0A172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF203E66)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.dispatchId,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE6F1FF),
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Decision UTC: ${d.occurredAt.toIso8601String()}',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF93A9C8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: statusColor.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.75),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.rajdhani(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (!isExecuted && !isDenied)
                                ElevatedButton(
                                  onPressed: () =>
                                      widget.onExecute(d.dispatchId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF165EA4),
                                    foregroundColor: const Color(0xFFE6F1FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Execute',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedDispatchIds.remove(d.dispatchId);
                                    } else {
                                      _expandedDispatchIds.add(d.dispatchId);
                                    }
                                  });
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E1A33),
                                  side: const BorderSide(
                                    color: Color(0xFF26456F),
                                  ),
                                ),
                                icon: Icon(
                                  isExpanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: const Color(0xFFB4C9E7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _queueMetaPill(d.siteId, const Color(0xFF88CCFF)),
                              _queueMetaPill(
                                '${dispatchResponses.length} responses',
                                dispatchResponses.isEmpty
                                    ? const Color(0xFF8EA4C2)
                                    : const Color(0xFF8CF1C3),
                              ),
                              _queueMetaPill(
                                closure == null
                                    ? 'Open incident'
                                    : 'Closed incident',
                                closure == null
                                    ? const Color(0xFFFFD6A5)
                                    : const Color(0xFF8CF1C3),
                              ),
                              _queueMetaPill(
                                isExecuted || isDenied
                                    ? 'Review trace'
                                    : 'Awaiting action',
                                isExecuted || isDenied
                                    ? const Color(0xFFB8C8FF)
                                    : const Color(0xFF9FD8AC),
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            _detailCard(
                              decision: d,
                              executed: executed,
                              denied: deniedEvt,
                              responses: dispatchResponses,
                              closure: closure,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (hiddenDecisions > 0) ...[
                  const SizedBox(height: 8),
                  OnyxTruncationHint(
                    visibleCount: visibleDecisions.length,
                    totalCount: decisions.length,
                    subject: 'dispatch decisions',
                  ),
                ],
              ],
            ),
    );
  }

  Widget _stressControlCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF09172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF142B49)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _profileSummaryBadge(
                'Feeds',
                '${_profile.feeds} x ${_profile.recordsPerFeed}',
              ),
              _profileSummaryBadge(
                'Burst',
                '${_profile.bursts} @ ${_profile.interBurstDelayMs}ms',
              ),
              _profileSummaryBadge(
                'Risk Mix',
                '${_profile.highRiskPercent}% high',
              ),
              _profileSummaryBadge(
                'Replay',
                _profile.verifyReplay ? 'verified' : 'off',
              ),
              _profileSummaryBadge(
                'Regression',
                _profile.stopOnRegression ? 'guarded' : 'manual',
              ),
              _profileSummaryBadge('Soak', '${_profile.soakRuns} runs'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 368,
              child: _workspaceGroupCard(
                title: 'Load Profile',
                subtitle:
                    'Shape ingest volume, replay characteristics, and spread before running.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...IntakeStressPreset.values.map(
                      (preset) => OutlinedButton(
                        onPressed: widget.stressRunning
                            ? null
                            : () => _updateProfile(preset.profile),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _profile == preset.profile
                              ? const Color(0xFFE6F7FF)
                              : const Color(0xFF95B3D8),
                          side: BorderSide(
                            color: _profile == preset.profile
                                ? const Color(0xFF5DA3D5)
                                : const Color(0xFF2A5E97),
                          ),
                        ),
                        child: Text(preset.label),
                      ),
                    ),
                    _selector(
                      label: 'Feeds',
                      value: _profile.feeds,
                      options: const [2, 3, 4, 6],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(feeds: v)),
                    ),
                    _selector(
                      label: 'Records/Feed',
                      value: _profile.recordsPerFeed,
                      options: const [100, 200, 500, 1000],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(recordsPerFeed: v)),
                    ),
                    _selector(
                      label: 'Bursts',
                      value: _profile.bursts,
                      options: const [1, 3, 5, 10],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(bursts: v)),
                    ),
                    _selector(
                      label: 'High Risk %',
                      value: _profile.highRiskPercent,
                      options: const [20, 35, 50, 70],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(highRiskPercent: v)),
                    ),
                    _selector(
                      label: 'Site Spread',
                      value: _profile.siteSpread,
                      options: const [1, 2, 3],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(siteSpread: v)),
                    ),
                    _selector(
                      label: 'Max Events',
                      value: _profile.maxAttemptedEvents,
                      options: const [20000, 60000, 120000],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(maxAttemptedEvents: v),
                      ),
                    ),
                    _selector(
                      label: 'Seed',
                      value: _profile.seed,
                      options: const [7, 42, 1337, 9001],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(seed: v)),
                    ),
                    _selector(
                      label: 'Chunk Size',
                      value: _profile.chunkSize,
                      options: const [300, 600, 1200, 2400],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(chunkSize: v)),
                    ),
                    _selector(
                      label: 'Dup %',
                      value: _profile.duplicatePercent,
                      options: const [0, 5, 10, 20],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(duplicatePercent: v),
                      ),
                    ),
                    _selector(
                      label: 'Burst Delay ms',
                      value: _profile.interBurstDelayMs,
                      options: const [0, 25, 100, 250],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(interBurstDelayMs: v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 324,
              child: _workspaceGroupCard(
                title: 'Guardrails',
                subtitle:
                    'Define replay validation, regression thresholds, and soak depth before execution.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        'Verify Replay',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE1EEFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: _profile.verifyReplay,
                      onSelected: (v) =>
                          _updateProfile(_profile.copyWith(verifyReplay: v)),
                      selectedColor: const Color(0xFF23456F),
                      checkmarkColor: const Color(0xFFCBE5FF),
                      side: const BorderSide(color: Color(0xFF2A5E97)),
                    ),
                    FilterChip(
                      label: Text(
                        'Stop On Regression',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE1EEFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: _profile.stopOnRegression,
                      onSelected: (v) => _updateProfile(
                        _profile.copyWith(stopOnRegression: v),
                      ),
                      selectedColor: const Color(0xFF3B2C1A),
                      checkmarkColor: const Color(0xFFFFE2B7),
                      side: const BorderSide(color: Color(0xFF8A7241)),
                    ),
                    _selector(
                      label: 'Thr Drop',
                      value: _profile.regressionThroughputDrop,
                      options: const [10, 20, 40],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(regressionThroughputDrop: v),
                      ),
                    ),
                    _selector(
                      label: 'Verify Rise',
                      value: _profile.regressionVerifyIncreaseMs,
                      options: const [50, 100, 200],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(regressionVerifyIncreaseMs: v),
                      ),
                    ),
                    _selector(
                      label: 'Max Pressure',
                      value: _profile.maxRegressionPressureSeverity,
                      options: const [1, 2],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(maxRegressionPressureSeverity: v),
                      ),
                    ),
                    _selector(
                      label: 'Max Imbalance',
                      value: _profile.maxRegressionImbalanceSeverity,
                      options: const [1, 2],
                      onChanged: (v) => _updateProfile(
                        _profile.copyWith(maxRegressionImbalanceSeverity: v),
                      ),
                    ),
                    _selector(
                      label: 'Soak Runs',
                      value: _profile.soakRuns,
                      options: const [1, 3, 5, 10],
                      onChanged: (v) =>
                          _updateProfile(_profile.copyWith(soakRuns: v)),
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
            SizedBox(
              width: 368,
              child: _workspaceGroupCard(
                title: 'Scenario Metadata',
                subtitle:
                    'Attach the current scenario label, operational tags, and controller note to the next run.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _textInput(
                      label: 'Scenario',
                      controller: _scenarioLabelController,
                      hintText: 'Hotspot replay',
                    ),
                    _textInput(
                      label: 'Tags',
                      controller: _scenarioTagsController,
                      hintText: 'soak, ingest, skew',
                    ),
                    _textInput(
                      label: 'Run Note',
                      controller: _runNoteController,
                      hintText: 'Operator annotation',
                      width: 236,
                      onChanged: _notifyRunNoteChanged,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 368,
              child: _workspaceGroupCard(
                title: 'Run Actions',
                subtitle:
                    'Launch burst, soak, and suite runs without losing the active profile context.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.stressRunning
                            ? null
                            : () => widget.onRunStress(_profile),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF216C3E),
                          foregroundColor: const Color(0xFFE9FFF0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: widget.stressRunning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(
                          widget.stressRunning
                              ? 'Running Stress...'
                              : 'Run Stress Burst',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Supporting Runs',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6F8FB6),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.stressRunning
                              ? null
                              : () => widget.onRunSoak(_profile),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE7D7A8),
                            side: const BorderSide(color: Color(0xFF8A7241)),
                          ),
                          icon: const Icon(Icons.timelapse_rounded),
                          label: Text(
                            _profile.soakRuns > 1
                                ? 'Run Soak x${_profile.soakRuns}'
                                : 'Run Soak',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.stressRunning
                              ? null
                              : widget.onRunBenchmarkSuite,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBFD8FF),
                            side: const BorderSide(color: Color(0xFF3B5F9A)),
                          ),
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: Text(
                            'Run Benchmark Suite',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.stressRunning
                              ? null
                              : widget.onRerunLastProfile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCFE6D9),
                            side: const BorderSide(color: Color(0xFF4E7B67)),
                          ),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(
                            'Rerun Last Profile',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.stressRunning)
                          OutlinedButton.icon(
                            onPressed: widget.onCancelStress,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFB0B8),
                              side: const BorderSide(color: Color(0xFF8A3D4A)),
                            ),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              'Cancel Run',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
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
        const SizedBox(height: 8),
        _workspaceGroupCard(
          title: 'Persistence, Import & Snapshot Tools',
          subtitle:
              'Reset, persist, import, and export operational state without mixing those actions into the runtime controls.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolCluster(
                    title: 'State',
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.stressRunning
                            ? null
                            : widget.onResetTelemetry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDDB28F),
                          side: const BorderSide(color: Color(0xFF7B5B41)),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          'Reset Telemetry',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.stressRunning
                            ? null
                            : widget.onClearTelemetryPersistence,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFD3A8),
                          side: const BorderSide(color: Color(0xFF8A5D41)),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text(
                          'Clear Saved History',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.onClearLivePollHealth != null)
                        OutlinedButton.icon(
                          onPressed: widget.stressRunning
                              ? null
                              : widget.onClearLivePollHealth,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC9E0FF),
                            side: const BorderSide(color: Color(0xFF4A648A)),
                          ),
                          icon: const Icon(Icons.sensors_off_rounded),
                          label: Text(
                            'Clear Poll Health',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (widget.onClearSavedViewsPersistence != null)
                        OutlinedButton.icon(
                          onPressed: widget.stressRunning
                              ? null
                              : widget.onClearSavedViewsPersistence,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBE7D4),
                            side: const BorderSide(color: Color(0xFF4A7A5C)),
                          ),
                          icon: const Icon(Icons.view_list_rounded),
                          label: Text(
                            'Clear Saved Views',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: widget.stressRunning
                            ? null
                            : widget.onClearProfilePersistence,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFC9B5),
                          side: const BorderSide(color: Color(0xFF8A5441)),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          'Clear Saved Draft',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  _toolCluster(
                    title: 'Telemetry',
                    children: [
                      OutlinedButton.icon(
                        onPressed: _copyTelemetryJson,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA9C6F7),
                          side: const BorderSide(color: Color(0xFF3F5E90)),
                        ),
                        icon: const Icon(Icons.content_copy_rounded),
                        label: Text(
                          'Copy Telemetry JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importTelemetryJson,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFAED8FF),
                          side: const BorderSide(color: Color(0xFF446A95)),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          'Import Telemetry JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyTelemetryCsv,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB5E3D1),
                          side: const BorderSide(color: Color(0xFF3E7C69)),
                        ),
                        icon: const Icon(Icons.table_chart_rounded),
                        label: Text(
                          'Copy Telemetry CSV',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  iconColor: const Color(0xFF8FD1FF),
                  collapsedIconColor: const Color(0xFF7EA5CB),
                  title: Text(
                    'Advanced Snapshot & Profile Tools',
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
                      runSpacing: 8,
                      children: [
                        _toolCluster(
                          title: 'Snapshots',
                          children: [
                            OutlinedButton.icon(
                              onPressed: _copySnapshotJson,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFCFE8FF),
                                side: const BorderSide(
                                  color: Color(0xFF55739A),
                                ),
                              ),
                              icon: const Icon(Icons.inventory_2_rounded),
                              label: Text(
                                'Copy Snapshot JSON',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1A33),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFF55739A),
                                ),
                              ),
                              child: Text(
                                'Snapshot v$_snapshotVersion',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFCFE8FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _downloadSnapshotFile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC9F4FF),
                                side: const BorderSide(
                                  color: Color(0xFF4A7891),
                                ),
                              ),
                              icon: const Icon(Icons.save_alt_rounded),
                              label: Text(
                                'Download Snapshot File',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _importSnapshotJson,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDCEBFF),
                                side: const BorderSide(
                                  color: Color(0xFF5F7FA7),
                                ),
                              ),
                              icon: const Icon(Icons.move_to_inbox_rounded),
                              label: Text(
                                'Import Snapshot JSON',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loadSnapshotFile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD8F7FF),
                                side: const BorderSide(
                                  color: Color(0xFF4F7D89),
                                ),
                              ),
                              icon: const Icon(Icons.folder_open_rounded),
                              label: Text(
                                'Load Snapshot File',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _toolCluster(
                          title: 'Profiles',
                          children: [
                            OutlinedButton.icon(
                              onPressed: _copyProfileJson,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE3D2FF),
                                side: const BorderSide(
                                  color: Color(0xFF6A5A93),
                                ),
                              ),
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(
                                'Copy Profile JSON',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _importProfileJson,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF3D8FF),
                                side: const BorderSide(
                                  color: Color(0xFF865C8A),
                                ),
                              ),
                              icon: const Icon(Icons.file_download_rounded),
                              label: Text(
                                'Import Profile JSON',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroStatTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF17355B)),
      ),
      child: Column(
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
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceGroupCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1629),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF142D4B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3A76B4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE6F1FF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _toolCluster({required String title, required List<Widget> children}) {
    return Container(
      width: 256,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1A2E), Color(0xFF091628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3C61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF86A2C8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: children),
        ],
      ),
    );
  }

  Widget _profileSummaryBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1C33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF173150)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 11),
          children: [
            const TextSpan(text: ''),
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF7F97B8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text: '',
              style: TextStyle(
                color: Color(0xFFE2EEFF),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFFE2EEFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyTelemetryJson() async {
    final telemetry = widget.intakeTelemetry;
    if (telemetry == null) return;
    final payload = _clipboard.exportTelemetryJson(telemetry);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showSnack('Telemetry JSON copied');
  }

  Future<void> _importTelemetryJson() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    try {
      final telemetry = _clipboard.importTelemetryJson(raw);
      widget.onTelemetryImported(telemetry);
      if (!mounted) return;
      _showSnack('Telemetry JSON imported');
    } on FormatException catch (error) {
      _showSnack(error.message);
    }
  }

  Future<void> _copyTelemetryCsv() async {
    final telemetry = widget.intakeTelemetry;
    if (telemetry == null) return;
    final csv = _clipboard.exportTelemetryCsv(telemetry);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    _showSnack('Telemetry CSV copied');
  }

  Future<void> _copyProfileJson() async {
    final payload = _clipboard.exportProfileJson(_profile);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showSnack('Profile JSON copied');
  }

  Future<void> _copySnapshotJson() async {
    final payload = _snapshotPayload;
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showSnack('Snapshot JSON v$_snapshotVersion copied');
  }

  Future<void> _downloadSnapshotFile() async {
    if (!_snapshotFiles.supported) {
      _showSnack('File export is only available on web');
      return;
    }
    await _snapshotFiles.downloadJsonFile(
      filename: _snapshotFilename,
      contents: _snapshotPayload,
    );
    if (!mounted) return;
    _showSnack('Snapshot file download started');
  }

  Future<void> _importProfileJson() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    try {
      final profile = _clipboard.importProfileJson(raw);
      _updateProfile(profile);
      if (!mounted) return;
      _showSnack('Profile JSON imported');
    } on FormatException catch (error) {
      _showSnack(error.message);
    }
  }

  Future<void> _importSnapshotJson() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    try {
      final snapshot = _clipboard.importSnapshotJson(raw);
      final request = await _confirmSnapshotImport(snapshot);
      if (request == null) return;
      _applySnapshot(
        snapshot,
        mode: request.mode,
        importDraftMetadata: request.importDraftMetadata,
        importSavedViews: request.importSavedViews,
        selectedPresetNames: request.selectedPresetNames,
      );
      if (!mounted) return;
      _showSnack('Snapshot JSON v${snapshot.version} imported');
    } on FormatException catch (error) {
      _showSnack(error.message);
    }
  }

  Future<void> _loadSnapshotFile() async {
    if (!_snapshotFiles.supported) {
      _showSnack('File import is only available on web');
      return;
    }
    try {
      final raw = await _snapshotFiles.pickJsonFile();
      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        _showSnack('No snapshot file selected');
        return;
      }
      final snapshot = _clipboard.importSnapshotJson(raw);
      final request = await _confirmSnapshotImport(snapshot);
      if (request == null) return;
      _applySnapshot(
        snapshot,
        mode: request.mode,
        importDraftMetadata: request.importDraftMetadata,
        importSavedViews: request.importSavedViews,
        selectedPresetNames: request.selectedPresetNames,
      );
      if (!mounted) return;
      _showSnack('Snapshot file v${snapshot.version} imported');
    } on FormatException catch (error) {
      _showSnack(error.message);
    }
  }

  void _applySnapshot(
    DispatchSnapshot snapshot, {
    required _SnapshotImportMode mode,
    required bool importDraftMetadata,
    required bool importSavedViews,
    Set<String>? selectedPresetNames,
  }) {
    final importSnapshot = _snapshotWithSelectedPresets(
      snapshot,
      selectedPresetNames,
    );
    if (importSavedViews) {
      final nextFilterPresets = mode == _SnapshotImportMode.replace
          ? List<DispatchBenchmarkFilterPreset>.from(
              importSnapshot.filterPresets,
            )
          : _mergeSnapshotFilterPresets(importSnapshot);
      setState(() {
        _savedFilterPresets = nextFilterPresets;
        _activeFilterPresetName = null;
      });
      widget.onFilterPresetsChanged?.call(nextFilterPresets);
    }
    if (importDraftMetadata) {
      _scenarioLabelController.text = snapshot.scenarioLabel;
      _scenarioTagsController.text = snapshot.tags.join(', ');
      _runNoteController.text = snapshot.runNote;
      _notifyScenarioChanged();
      _notifyRunNoteChanged();
      _updateProfile(snapshot.profile);
      widget.onTelemetryImported(snapshot.telemetry);
    }
  }

  DispatchSnapshot _snapshotWithSelectedPresets(
    DispatchSnapshot snapshot,
    Set<String>? selectedPresetNames,
  ) {
    if (selectedPresetNames == null) {
      return snapshot;
    }
    final filteredPresets = snapshot.filterPresets
        .where((preset) => selectedPresetNames.contains(preset.name))
        .toList(growable: false);
    return DispatchSnapshot(
      version: snapshot.version,
      scenarioLabel: snapshot.scenarioLabel,
      tags: snapshot.tags,
      runNote: snapshot.runNote,
      filterPresets: filteredPresets,
      profile: snapshot.profile,
      telemetry: snapshot.telemetry,
    );
  }

  Widget _snapshotInspectLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: const Color(0xFFB9CCE6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _snapshotInspectContinuationLine(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 12),
      child: Text(
        value,
        style: GoogleFonts.inter(
          color: const Color(0xFFB9CCE6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _snapshotTags => _scenarioTagsController.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  List<String> _snapshotCollidingPresetNames(DispatchSnapshot snapshot) {
    if (_savedFilterPresets.isEmpty || snapshot.filterPresets.isEmpty) {
      return const [];
    }
    final currentNames = _savedFilterPresets
        .map((preset) => preset.name)
        .toSet();
    return snapshot.filterPresets
        .where((preset) => currentNames.contains(preset.name))
        .map((preset) => preset.name)
        .toList(growable: false);
  }

  List<String> _snapshotIncomingPresetNames(DispatchSnapshot snapshot) {
    if (snapshot.filterPresets.isEmpty) {
      return const [];
    }
    return snapshot.filterPresets
        .map((preset) => preset.name)
        .toList(growable: false);
  }

  List<String> _snapshotIncomingOnlyPresetNames(DispatchSnapshot snapshot) {
    if (snapshot.filterPresets.isEmpty) {
      return const [];
    }
    final currentNames = _savedFilterPresets
        .map((preset) => preset.name)
        .toSet();
    return snapshot.filterPresets
        .where((preset) => !currentNames.contains(preset.name))
        .map((preset) => preset.name)
        .toList(growable: false);
  }

  List<String> _snapshotCollisionDiffLines(DispatchSnapshot snapshot) {
    if (_savedFilterPresets.isEmpty || snapshot.filterPresets.isEmpty) {
      return const [];
    }
    final currentByName = {
      for (final preset in _savedFilterPresets) preset.name: preset,
    };
    final lines = <String>[];
    for (final incoming in snapshot.filterPresets) {
      final existing = currentByName[incoming.name];
      if (existing == null) continue;
      final details = _filterPresetChangeDetails(existing, incoming);
      if (details.isEmpty) {
        lines.add('${incoming.name}: none');
        continue;
      }
      lines.add('${incoming.name}:');
      for (final detail in details) {
        lines.add('- $detail');
      }
    }
    return lines;
  }

  int _snapshotUnchangedCollisions(DispatchSnapshot snapshot) {
    if (_savedFilterPresets.isEmpty || snapshot.filterPresets.isEmpty) {
      return 0;
    }
    final currentByName = {
      for (final preset in _savedFilterPresets) preset.name: preset,
    };
    int count = 0;
    for (final incoming in snapshot.filterPresets) {
      final existing = currentByName[incoming.name];
      if (existing == null) continue;
      if (_filterPresetChangeDetails(existing, incoming).isEmpty) {
        count++;
      }
    }
    return count;
  }

  List<DispatchBenchmarkFilterPreset> _mergeSnapshotFilterPresets(
    DispatchSnapshot snapshot,
  ) {
    final mergedByName = {
      for (final preset in _savedFilterPresets) preset.name: preset,
      for (final preset in snapshot.filterPresets) preset.name: preset,
    };
    final merged = mergedByName.values.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return merged;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DispatchBenchmarkFilterPreset? _findFilterPresetByName(String? name) {
    if (name == null) return null;
    for (final preset in _savedFilterPresets) {
      if (preset.name == name) return preset;
    }
    return null;
  }

  DispatchBenchmarkSort _sortFromName(String name) {
    for (final sort in DispatchBenchmarkSort.values) {
      if (sort.name == name) return sort;
    }
    return DispatchBenchmarkSort.latest;
  }

  String _formatPresetTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null) return raw;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}Z';
  }

  String get _snapshotPayload => _clipboard.exportSnapshotJson(
    scenarioLabel: _scenarioLabelController.text.trim(),
    tags: _snapshotTags,
    runNote: _runNoteController.text.trim(),
    filterPresets: _savedFilterPresets,
    profile: _profile,
    telemetry: widget.intakeTelemetry ?? IntakeTelemetry.zero,
  );

  int get _snapshotVersion => DispatchSnapshot(
    profile: _profile,
    telemetry: widget.intakeTelemetry ?? IntakeTelemetry.zero,
  ).version;

  String get _snapshotFilename {
    final normalized = _scenarioLabelController.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final suffix = normalized.isEmpty ? 'dispatch_snapshot' : normalized;
    return 'onyx_$suffix.json';
  }

  String get _activeScenarioLabel {
    final value = _scenarioLabelController.text.trim();
    return value.isEmpty ? 'N/A' : value;
  }

  String get _activeScenarioTagsLabel {
    final tags = _snapshotTags;
    return tags.isEmpty ? 'N/A' : tags.join(', ');
  }

  String get _activeRunNoteLabel {
    final value = _runNoteController.text.trim();
    return value.isEmpty ? 'N/A' : value;
  }

  Widget _telemetryCard(IntakeTelemetry telemetry) {
    final lastRun = telemetry.recentRuns.firstOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _metricChip('Scenario', _activeScenarioLabel),
          _metricChip('Tags', _activeScenarioTagsLabel),
          _metricChip('Run Note', _activeRunNoteLabel),
          _metricChip('Runs', telemetry.runs.toString()),
          _metricChip('Total Appended', telemetry.totalAppended.toString()),
          _metricChip('Total Skipped', telemetry.totalSkipped.toString()),
          _metricChip('Decisions', telemetry.totalDecisions.toString()),
          _metricChip(
            'Last Throughput',
            '${telemetry.lastThroughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'Avg Throughput',
            '${telemetry.averageThroughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'Median Throughput',
            '${DispatchBenchmarkPresenter.medianThroughput(telemetry.recentRuns).toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'Best Throughput',
            '${telemetry.bestThroughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'Worst Throughput',
            '${telemetry.worstThroughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'P50 Throughput',
            '${telemetry.lastP50Throughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'P95 Throughput',
            '${telemetry.lastP95Throughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip('Last Verify', '${telemetry.lastVerifyMs} ms'),
          _metricChip(
            'Avg Verify',
            '${telemetry.averageVerifyMs.toStringAsFixed(1)} ms',
          ),
          _metricChip(
            'Best Verify',
            '${telemetry.bestVerifyMs.toStringAsFixed(0)} ms',
          ),
          _metricChip(
            'Worst Verify',
            '${telemetry.worstVerifyMs.toStringAsFixed(0)} ms',
          ),
          _metricChip(
            'Avg Chunk',
            '${telemetry.averageChunkMs.toStringAsFixed(1)} ms',
          ),
          _metricChip('Last Max Chunk', '${telemetry.lastMaxChunkMs} ms'),
          _metricChip('Slow Chunks', telemetry.totalSlowChunks.toString()),
          _metricChip('Peak Pending', telemetry.peakPending.toString()),
          _metricChip(
            'Dup Injected',
            telemetry.totalDuplicatesInjected.toString(),
          ),
          _metricChip(
            'Last Pressure',
            lastRun == null ? 'N/A' : _pressureLabel(lastRun),
          ),
          _metricChip(
            'Top Site',
            lastRun == null ? 'N/A' : _hotspotLabel(lastRun.hottestSite),
          ),
          _metricChip(
            'Top Feed',
            lastRun == null ? 'N/A' : _hotspotLabel(lastRun.hottestFeed),
          ),
          _metricChip(
            'Imbalance',
            lastRun == null
                ? 'N/A'
                : '${(lastRun.imbalanceScore * 100).toStringAsFixed(0)}%',
          ),
          _metricChip('Last Soak Runs', telemetry.lastSoakRuns.toString()),
          _metricChip(
            'Soak Thr Drift',
            '${telemetry.lastSoakDriftThroughput.toStringAsFixed(1)} ev/s',
          ),
          _metricChip(
            'Soak Verify Drift',
            '${telemetry.lastSoakDriftVerifyMs} ms',
          ),
          _metricChip('Last Burst', telemetry.lastBurstSize.toString()),
          _metricChip(
            'Trend',
            DispatchBenchmarkPresenter.throughputTrend(telemetry.recentRuns),
          ),
        ],
      ),
    );
  }

  Widget _intelligenceBriefingCard(
    List<IntelligenceReceived> items, {
    required List<IntelligenceReceived> allIntel,
    required List<DecisionCreated> decisions,
  }) {
    final scopedAllItems = widget.events
        .whereType<IntelligenceReceived>()
        .where((item) {
          return item.clientId == widget.clientId &&
              item.regionId == widget.regionId &&
              item.siteId == widget.siteId &&
              _newsIntelSourceTypes.contains(item.sourceType);
        })
        .toList(growable: false);
    final dismissedItems = scopedAllItems
        .where((item) {
          return _dismissedIntelligenceIds.contains(item.intelligenceId);
        })
        .toList(growable: false);
    final sourceFilteredItems = _intelligenceSourceFilter == 'all'
        ? items
        : items
              .where((item) => item.sourceType == _intelligenceSourceFilter)
              .toList(growable: false);
    final sourceFilteredDismissed = _intelligenceSourceFilter == 'all'
        ? dismissedItems
        : dismissedItems
              .where((item) => item.sourceType == _intelligenceSourceFilter)
              .toList(growable: false);
    final sourceFilteredPinned = sourceFilteredItems
        .where((item) {
          return _pinnedWatchIntelligenceIds.contains(item.intelligenceId);
        })
        .toList(growable: false);
    final scopedItems = _showDismissedIntelligenceOnly
        ? sourceFilteredDismissed
        : _showPinnedWatchIntelligenceOnly
        ? sourceFilteredPinned
        : sourceFilteredItems;
    final filteredItems = scopedItems
        .where((item) {
          if (_intelligenceActionFilter == 'all') {
            return true;
          }
          return _intelligenceActionLabel(
                item,
                allIntel: allIntel,
                decisions: decisions,
              ) ==
              _intelligenceActionFilter;
        })
        .toList(growable: false);
    final visibleItems = filteredItems.take(8).toList(growable: false);
    final hiddenItems = filteredItems.length - visibleItems.length;
    final highRiskCount = filteredItems
        .where((item) => item.riskScore >= 70)
        .length;
    final providerCount = filteredItems
        .map((item) => item.provider)
        .toSet()
        .length;
    final pinnedWatchCount = filteredItems.where((item) {
      return _pinnedWatchIntelligenceIds.contains(item.intelligenceId);
    }).length;
    final peakRisk = filteredItems.fold<int>(
      0,
      (current, item) => item.riskScore > current ? item.riskScore : current,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Intelligence',
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE5FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metricChip('Relevant Intel', filteredItems.length.toString()),
              _metricChip('High Risk', highRiskCount.toString()),
              _metricChip('Sources', providerCount.toString()),
              _metricChip(
                'Pinned Watches',
                pinnedWatchCount.toString(),
                selected: _showPinnedWatchIntelligenceOnly,
                onTap: () {
                  final enablePinnedOnly = !_showPinnedWatchIntelligenceOnly;
                  _setPinnedWatchIntelligenceView(enablePinnedOnly);
                  if (enablePinnedOnly && _intelligenceActionFilter != 'all') {
                    _setIntelligenceFilters(actionFilter: 'all');
                  }
                },
              ),
              _metricChip(
                'Dismissed',
                sourceFilteredDismissed.length.toString(),
                selected: _showDismissedIntelligenceOnly,
                onTap: () {
                  _setDismissedIntelligenceView(
                    !_showDismissedIntelligenceOnly,
                  );
                },
              ),
              _metricChip('Peak Risk', peakRisk.toString()),
              if (_intelligenceSourceFilter != 'all' ||
                  _intelligenceActionFilter != 'all' ||
                  _showPinnedWatchIntelligenceOnly ||
                  _showDismissedIntelligenceOnly)
                GestureDetector(
                  onTap: () {
                    _setPinnedWatchIntelligenceView(false);
                    _setDismissedIntelligenceView(false);
                    _setIntelligenceFilters(
                      sourceFilter: 'all',
                      actionFilter: 'all',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13253D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF476B94)),
                    ),
                    child: Text(
                      'Clear Filters',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD8ECFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _intelFilterLabels.entries
                .map((entry) {
                  final selected = _intelligenceSourceFilter == entry.key;
                  return GestureDetector(
                    onTap: () {
                      if (selected) return;
                      _setIntelligenceFilters(sourceFilter: entry.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF173253)
                            : const Color(0xFF10213A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF5D91C6)
                              : const Color(0xFF36567E),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: GoogleFonts.inter(
                          color: selected
                              ? const Color(0xFFE5F1FF)
                              : const Color(0xFFB9CCE6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _intelActionFilterLabels.entries
                .map((entry) {
                  final selected = _intelligenceActionFilter == entry.key;
                  return GestureDetector(
                    onTap: () {
                      if (selected) return;
                      _setIntelligenceFilters(actionFilter: entry.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF173253)
                            : const Color(0xFF10213A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF5D91C6)
                              : const Color(0xFF36567E),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: GoogleFonts.inter(
                          color: selected
                              ? const Color(0xFFE5F1FF)
                              : const Color(0xFFB9CCE6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: visibleItems.isEmpty
                ? Center(
                    child: Text(
                      'No intelligence items match this filter.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final selected =
                          item.intelligenceId == _selectedIntelligenceId;
                      final riskColor = item.riskScore >= 80
                          ? const Color(0xFFFFA3AF)
                          : item.riskScore >= 70
                          ? const Color(0xFFFFD6A5)
                          : const Color(0xFFAFCAE9);
                      final actionLabel = _intelligenceActionLabel(
                        item,
                        allIntel: allIntel,
                        decisions: decisions,
                      );
                      final assessment = _intelligenceAssessment(
                        item,
                        allIntel: allIntel,
                        decisions: decisions,
                      );
                      final actionColor = _intelligenceActionColor(actionLabel);
                      return InkWell(
                        onTap: () {
                          _selectIntelligence(item.intelligenceId);
                          _showIntelligenceDetail(
                            item,
                            assessment: assessment,
                            actionLabel: actionLabel,
                            actionColor: actionColor,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0x141F6AA5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF5D91C6)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10213A),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF36567E),
                                        ),
                                      ),
                                      child: Text(
                                        item.riskScore.toString(),
                                        style: GoogleFonts.inter(
                                          color: riskColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10213A),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color:
                                              assessment.predictiveScore >= 80
                                              ? const Color(0xFFFFA3AF)
                                              : assessment.predictiveScore >= 60
                                              ? const Color(0xFFFFD6A5)
                                              : const Color(0xFF9FD8AC),
                                        ),
                                      ),
                                      child: Text(
                                        'P${assessment.predictiveScore}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFCEE5FF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.headline,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFE5F1FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${item.provider} • ${item.occurredAt.toIso8601String()}',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF8EA4C2),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10213A),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: actionColor,
                                              ),
                                            ),
                                            child: Text(
                                              actionLabel,
                                              style: GoogleFonts.inter(
                                                color: actionColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (assessment.corroborated)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10213A),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF5D91C6,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                'Corroborated',
                                                style: GoogleFonts.inter(
                                                  color: const Color(
                                                    0xFFAFCAE9,
                                                  ),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          if (selected)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF173253),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF5D91C6,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                'Selected',
                                                style: GoogleFonts.inter(
                                                  color: const Color(
                                                    0xFFE5F1FF,
                                                  ),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.summary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFB9CCE6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                  ),
          ),
          if (hiddenItems > 0) ...[
            const SizedBox(height: 8),
            OnyxTruncationHint(
              visibleCount: visibleItems.length,
              totalCount: filteredItems.length,
              subject: 'intelligence rows',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showIntelligenceDetail(
    IntelligenceReceived item, {
    required IntelligenceTriageAssessment assessment,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final pinnedWatch = _pinnedWatchIntelligenceIds.contains(
      item.intelligenceId,
    );
    final dismissed = _dismissedIntelligenceIds.contains(item.intelligenceId);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            'Intelligence Detail',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _snapshotInspectLine('Headline', item.headline),
                _snapshotInspectLine('Action', actionLabel),
                _snapshotInspectLine('Source Type', item.sourceType),
                _snapshotInspectLine('Provider', item.provider),
                _snapshotInspectLine('Risk', item.riskScore.toString()),
                _snapshotInspectLine(
                  'Predictive Score',
                  assessment.predictiveScore.toString(),
                ),
                _snapshotInspectLine(
                  'Corroborated',
                  assessment.corroborated ? 'yes' : 'no',
                ),
                _snapshotInspectLine(
                  'Recent Dispatch Nearby',
                  assessment.recentDispatchNearby ? 'yes' : 'no',
                ),
                _snapshotInspectLine(
                  'Matched Signals',
                  assessment.matchedSignals.isEmpty
                      ? 'none'
                      : assessment.matchedSignals.join(', '),
                ),
                _snapshotInspectLine(
                  'Rationale',
                  assessment.rationale.join(' | '),
                ),
                _snapshotInspectLine(
                  'Pinned Watch',
                  pinnedWatch ? 'yes' : 'no',
                ),
                _snapshotInspectLine('Dismissed', dismissed ? 'yes' : 'no'),
                _snapshotInspectLine(
                  'Occurred',
                  item.occurredAt.toIso8601String(),
                ),
                _snapshotInspectLine('External', item.externalId),
                _snapshotInspectLine('Intel ID', item.intelligenceId),
                _snapshotInspectLine('Summary', item.summary),
              ],
            ),
          ),
          actions: [
            if (!pinnedWatch && !dismissed)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _pinIntelligenceWatch(item);
                },
                child: Text(
                  'Pin as Watch',
                  style: GoogleFonts.inter(color: const Color(0xFFFFD6A5)),
                ),
              ),
            if (widget.onEscalateIntelligence != null && !dismissed)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEscalateIntelligence!(item);
                },
                child: Text(
                  assessment.shouldEscalate
                      ? 'Escalate to Dispatch'
                      : 'Manual Escalate Override',
                  style: GoogleFonts.inter(
                    color: assessment.shouldEscalate
                        ? const Color(0xFFFFA3AF)
                        : const Color(0xFFFFD6A5),
                  ),
                ),
              ),
            if (dismissed) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restoreDismissedIntelligence(item);
                },
                child: Text(
                  'Restore Intel',
                  style: GoogleFonts.inter(color: const Color(0xFF9FD8AC)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restoreDismissedIntelligence(item, pinAsWatch: true);
                },
                child: Text(
                  'Restore & Pin',
                  style: GoogleFonts.inter(color: const Color(0xFFFFD6A5)),
                ),
              ),
            ] else
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _dismissIntelligence(item);
                },
                child: Text(
                  'Dismiss / Ignore',
                  style: GoogleFonts.inter(color: const Color(0xFF9FD8AC)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: actionColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _pinIntelligenceWatch(IntelligenceReceived item) {
    if (_pinnedWatchIntelligenceIds.contains(item.intelligenceId)) {
      _selectIntelligence(item.intelligenceId);
      return;
    }
    setState(() {
      _pinnedWatchIntelligenceIds.add(item.intelligenceId);
      _dismissedIntelligenceIds.remove(item.intelligenceId);
      _selectedIntelligenceId = item.intelligenceId;
    });
    _persistIntelligenceTriage();
    widget.onSelectedIntelligenceChanged?.call(item.intelligenceId);
    _showSnack('Pinned intelligence as watch');
  }

  void _dismissIntelligence(IntelligenceReceived item) {
    if (_dismissedIntelligenceIds.contains(item.intelligenceId)) {
      return;
    }
    setState(() {
      _dismissedIntelligenceIds.add(item.intelligenceId);
      _pinnedWatchIntelligenceIds.remove(item.intelligenceId);
      if (_selectedIntelligenceId == item.intelligenceId) {
        _selectedIntelligenceId = '';
      }
    });
    _persistIntelligenceTriage();
    if (_selectedIntelligenceId.isEmpty) {
      widget.onSelectedIntelligenceChanged?.call('');
    }
    _showSnack('Intelligence dismissed');
  }

  void _restoreDismissedIntelligence(
    IntelligenceReceived item, {
    bool pinAsWatch = false,
  }) {
    if (!_dismissedIntelligenceIds.contains(item.intelligenceId)) {
      return;
    }
    setState(() {
      _dismissedIntelligenceIds.remove(item.intelligenceId);
      if (pinAsWatch) {
        _pinnedWatchIntelligenceIds.add(item.intelligenceId);
      }
      _selectedIntelligenceId = item.intelligenceId;
    });
    _persistIntelligenceTriage();
    widget.onSelectedIntelligenceChanged?.call(item.intelligenceId);
    _showSnack(
      pinAsWatch ? 'Intelligence restored and pinned' : 'Intelligence restored',
    );
  }

  String _intelligenceActionLabel(
    IntelligenceReceived item, {
    required List<IntelligenceReceived> allIntel,
    required List<DecisionCreated> decisions,
  }) {
    final assessment = _intelligenceAssessment(
      item,
      allIntel: allIntel,
      decisions: decisions,
    );
    return assessment.recommendation.label;
  }

  IntelligenceTriageAssessment _intelligenceAssessment(
    IntelligenceReceived item, {
    required List<IntelligenceReceived> allIntel,
    required List<DecisionCreated> decisions,
  }) {
    return _triagePolicy.evaluateReceived(
      item: item,
      allIntel: allIntel,
      decisions: decisions,
      pinnedWatch: _pinnedWatchIntelligenceIds.contains(item.intelligenceId),
      dismissed: _dismissedIntelligenceIds.contains(item.intelligenceId),
    );
  }

  Color _intelligenceActionColor(String actionLabel) {
    if (actionLabel == 'Dispatch Candidate') {
      return const Color(0xFFFFA3AF);
    }
    if (actionLabel == 'Watch') {
      return const Color(0xFFFFD6A5);
    }
    return const Color(0xFF9FD8AC);
  }

  Widget _benchmarkHistory(IntakeTelemetry telemetry) {
    if (telemetry.recentRuns.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableRuns = telemetry.recentRuns
        .where((run) => _showCancelledRuns || !run.cancelled)
        .toList(growable: false);
    final scenarioOptions =
        availableRuns
            .map((run) => run.scenarioLabel.trim())
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final activeScenarioFilter =
        scenarioOptions.contains(_historyScenarioFilter)
        ? _historyScenarioFilter
        : null;
    final tagOptions =
        availableRuns
            .expand((run) => run.tags)
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final activeTagFilter = tagOptions.contains(_historyTagFilter)
        ? _historyTagFilter
        : null;
    final activeNoteFilter = _historyNoteFilterController.text.trim();
    final filtered = availableRuns
        .where(
          (run) => activeScenarioFilter == null
              ? true
              : run.scenarioLabel == activeScenarioFilter,
        )
        .where(
          (run) => activeTagFilter == null
              ? true
              : run.tags.contains(activeTagFilter),
        )
        .where(
          (run) => activeNoteFilter.isEmpty
              ? true
              : run.note.toLowerCase().contains(activeNoteFilter.toLowerCase()),
        )
        .take(_historyLimit)
        .toList(growable: false);
    final activeBaselineRunLabel =
        filtered.any((run) => run.label == _baselineRunLabel)
        ? _baselineRunLabel
        : null;
    final activeStatusLabel =
        _statusFilters.length == _defaultHistoryStatuses.length
        ? 'all'
        : (() {
            final statuses = _statusFilters.toList(growable: false)..sort();
            return statuses.join(', ');
          })();

    final statusRows = DispatchBenchmarkPresenter.buildRows(
      runs: telemetry.recentRuns,
      showCancelledRuns: _showCancelledRuns,
      historyLimit: _historyLimit,
      baselineRunLabel: activeBaselineRunLabel,
      scenarioFilter: activeScenarioFilter,
      tagFilter: activeTagFilter,
      noteFilter: activeNoteFilter,
      statusFilters: _statusFilters,
      sort: _historySort,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Benchmarks',
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE5FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Showing ${statusRows.length}/${availableRuns.length} runs',
            style: GoogleFonts.inter(
              color: const Color(0xFFAFCAE9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _saveCurrentFilterPreset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD8ECFF),
                  side: const BorderSide(color: Color(0xFF567AA1)),
                ),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: Text(
                  'Save View',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _activeFilterPresetName,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('View: none'),
                      ),
                      ..._savedFilterPresets.map(
                        (preset) => DropdownMenuItem<String?>(
                          value: preset.name,
                          child: Text('View: ${preset.name}'),
                        ),
                      ),
                    ],
                    onChanged: (name) =>
                        _applyFilterPreset(_findFilterPresetByName(name)),
                  ),
                ),
              ),
              if (_activeFilterPresetName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isActiveFilterPresetDirty
                        ? const Color(0xFF3A2514)
                        : const Color(0xFF173253),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _isActiveFilterPresetDirty
                          ? const Color(0xFF9A6D3F)
                          : const Color(0xFF4D7BAA),
                    ),
                  ),
                  child: Text(
                    _isActiveFilterPresetDirty ? 'View Dirty' : 'View Synced',
                    style: GoogleFonts.inter(
                      color: _isActiveFilterPresetDirty
                          ? const Color(0xFFFFD6A5)
                          : const Color(0xFFD8ECFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_activeFilterPresetName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13253D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF476B94)),
                  ),
                  child: Text(
                    'Rev ${_findFilterPresetByName(_activeFilterPresetName)?.revision ?? 1}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD8ECFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if ((_findFilterPresetByName(
                        _activeFilterPresetName,
                      )?.updatedAtUtc ??
                      '')
                  .isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13253D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF476B94)),
                  ),
                  child: Text(
                    'Updated ${_formatPresetTimestamp(_findFilterPresetByName(_activeFilterPresetName)!.updatedAtUtc)}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFBFD8FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _activeFilterPresetName == null
                    ? null
                    : _renameActiveFilterPreset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE7D7FF),
                  side: const BorderSide(color: Color(0xFF6A5E92)),
                ),
                icon: const Icon(Icons.drive_file_rename_outline_rounded),
                label: Text(
                  'Rename View',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _activeFilterPresetName == null
                    ? null
                    : _copyActiveFilterPresetJson,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD6F4FF),
                  side: const BorderSide(color: Color(0xFF4E7F8F)),
                ),
                icon: const Icon(Icons.copy_all_rounded),
                label: Text(
                  'Copy View JSON',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _activeFilterPresetName == null
                    ? null
                    : _downloadActiveFilterPresetFile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD8F2FF),
                  side: const BorderSide(color: Color(0xFF4F7E9A)),
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  'Download View File',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _importFilterPresetJson,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD9F6EE),
                  side: const BorderSide(color: Color(0xFF4A7E71)),
                ),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(
                  'Import View JSON',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadFilterPresetFile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE2F7D8),
                  side: const BorderSide(color: Color(0xFF5F8650)),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  'Load View File',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _activeFilterPresetName == null ||
                        !_isActiveFilterPresetDirty
                    ? null
                    : _overwriteActiveFilterPreset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD9FFD8),
                  side: const BorderSide(color: Color(0xFF4F8A5E)),
                ),
                icon: const Icon(Icons.save_as_rounded),
                label: Text(
                  'Overwrite View',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _activeFilterPresetName == null
                    ? null
                    : _deleteActiveFilterPreset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD6B2),
                  side: const BorderSide(color: Color(0xFF8A5F45)),
                ),
                icon: const Icon(Icons.bookmark_remove_rounded),
                label: Text(
                  'Delete View',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_savedFilterPresets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _savedFilterPresets.map((preset) {
                final isActive = preset.name == _activeFilterPresetName;
                final isDirty = isActive && _isActiveFilterPresetDirty;
                final backgroundColor = isActive
                    ? (isDirty
                          ? const Color(0xFF3A2514)
                          : const Color(0xFF173253))
                    : const Color(0xFF10213A);
                final borderColor = isActive
                    ? (isDirty
                          ? const Color(0xFF9A6D3F)
                          : const Color(0xFF4D7BAA))
                    : const Color(0xFF36567E);
                final textColor = isActive
                    ? (isDirty
                          ? const Color(0xFFFFD6A5)
                          : const Color(0xFFD8ECFF))
                    : const Color(0xFFBFD8FF);
                return InkWell(
                  onTap: () => _applyFilterPreset(preset),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      '${preset.name} • Rev ${preset.revision}'
                      '${preset.updatedAtUtc.isEmpty ? '' : ' • ${_formatPresetTimestamp(preset.updatedAtUtc)}'}',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Active Filters: '
            'scenario ${activeScenarioFilter ?? 'all'} • '
            'tag ${activeTagFilter ?? 'all'} • '
            'note ${activeNoteFilter.isEmpty ? 'all' : activeNoteFilter} • '
            'status $activeStatusLabel • '
            'baseline ${activeBaselineRunLabel ?? 'none'}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _trendChart(filtered),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Show Cancelled'),
                selected: _showCancelledRuns,
                onSelected: (v) => setState(() => _showCancelledRuns = v),
                selectedColor: const Color(0xFF23456F),
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFFE1EEFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...['BASELINE', 'IMPROVED', 'STABLE', 'DEGRADED'].map(
                (status) => FilterChip(
                  label: Text(status),
                  selected: _statusFilters.contains(status),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _statusFilters.add(status);
                      } else {
                        _statusFilters.remove(status);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF23456F),
                  labelStyle: GoogleFonts.inter(
                    color: const Color(0xFFE1EEFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _clearHistoryFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBFD8FF),
                  side: const BorderSide(color: Color(0xFF3B5F9A)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: Text(
                  'Clear Filters',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: TextField(
                  controller: _historyNoteFilterController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE5F1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Filter note text',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF5E7598),
                      fontSize: 11,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _historyLimit,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: const [3, 6]
                        .map(
                          (option) => DropdownMenuItem<int>(
                            value: option,
                            child: Text('History: $option'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _historyLimit = v);
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: activeScenarioFilter,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Scenario: all'),
                      ),
                      ...scenarioOptions.map(
                        (label) => DropdownMenuItem<String?>(
                          value: label,
                          child: Text('Scenario: $label'),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _historyScenarioFilter = v),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: activeTagFilter,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tag: all'),
                      ),
                      ...tagOptions.map(
                        (tag) => DropdownMenuItem<String?>(
                          value: tag,
                          child: Text('Tag: $tag'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _historyTagFilter = v),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: activeBaselineRunLabel,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Baseline: none'),
                      ),
                      ...filtered.map(
                        (run) => DropdownMenuItem<String?>(
                          value: run.label,
                          child: Text('Baseline: ${run.label}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _baselineRunLabel = v),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF26456F)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DispatchBenchmarkSort>(
                    value: _historySort,
                    dropdownColor: const Color(0xFF081326),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5F1FF),
                      fontSize: 11,
                    ),
                    items: DispatchBenchmarkSort.values
                        .map(
                          (s) => DropdownMenuItem<DispatchBenchmarkSort>(
                            value: s,
                            child: Text('Sort: ${s.label}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _historySort = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (statusRows.isEmpty)
            Text(
              'No benchmark runs match the current filters.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ...statusRows.map((row) {
            final run = row.run;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (run.scenarioLabel.isNotEmpty || run.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (run.scenarioLabel.isNotEmpty)
                            _historyMetaChip(
                              'Run Scenario',
                              run.scenarioLabel,
                              const Color(0xFF89C9FF),
                              const Color(0xFF284A72),
                              selected:
                                  run.scenarioLabel == activeScenarioFilter,
                              onTap: () {
                                setState(
                                  () => _historyScenarioFilter =
                                      run.scenarioLabel == activeScenarioFilter
                                      ? null
                                      : run.scenarioLabel,
                                );
                              },
                            ),
                          ...run.tags.map(
                            (tag) => _historyMetaChip(
                              'Run Tag',
                              tag,
                              const Color(0xFFCDE8BA),
                              const Color(0xFF46683A),
                              selected: tag == activeTagFilter,
                              onTap: () {
                                setState(
                                  () => _historyTagFilter =
                                      tag == activeTagFilter ? null : tag,
                                );
                              },
                            ),
                          ),
                          TextButton(
                            onPressed: () => _editRunMetadata(telemetry, run),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFBFD8FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Edit Meta',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (run.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _historyMetaChip(
                            'Run Note',
                            run.note,
                            const Color(0xFFFFD6A5),
                            const Color(0xFF8A6A41),
                            selected:
                                activeNoteFilter.isNotEmpty &&
                                run.note.toLowerCase().contains(
                                  activeNoteFilter.toLowerCase(),
                                ),
                            onTap: () {
                              final note = run.note;
                              setState(() {
                                _historyNoteFilterController.text =
                                    activeNoteFilter.toLowerCase() ==
                                        note.toLowerCase()
                                    ? ''
                                    : note;
                              });
                            },
                          ),
                          TextButton(
                            onPressed: () => _editRunNote(telemetry, run),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFBFD8FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Edit Note',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    row.summary,
                    style: GoogleFonts.inter(
                      color: switch (row.tone) {
                        DispatchBenchmarkTone.positive => const Color(
                          0xFF8EF5B8,
                        ),
                        DispatchBenchmarkTone.negative => const Color(
                          0xFFFFA3AF,
                        ),
                        DispatchBenchmarkTone.neutral => const Color(
                          0xFF9FB6D5,
                        ),
                      },
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveIngestHistory(IntakeTelemetry telemetry) {
    final liveRuns = telemetry.recentRuns
        .where((run) => run.sourceLabel.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (liveRuns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Live Ingests',
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE5FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final run in liveRuns)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metricChip('Run', run.label),
                  _metricChip('Source', run.sourceLabel),
                  _metricChip('Appended', run.appended.toString()),
                  _metricChip('Skipped', run.skipped.toString()),
                  _metricChip('Decisions', run.decisions.toString()),
                  _metricChip('Feeds', run.uniqueFeeds.toString()),
                  _metricChip('Top Feed', _hotspotLabel(run.hottestFeed)),
                  _metricChip('Top Site', _hotspotLabel(run.hottestSite)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _livePollingHistoryCard(List<String> entries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Poll Health',
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE5FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                entry,
                style: GoogleFonts.inter(
                  color: const Color(0xFFB9CCE6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyMetaChip(
    String label,
    String value,
    Color foreground,
    Color border, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF173253) : const Color(0xFF0E1A33),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          '$label: $value',
          style: GoogleFonts.inter(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  int _pressureSeverity(IntakeRunSummary run) => run.pressureSeverity;

  String _pressureLabel(IntakeRunSummary run) {
    return switch (_pressureSeverity(run)) {
      2 => 'HIGH',
      1 => 'ELEVATED',
      _ => 'LOW',
    };
  }

  String _hotspotLabel(MapEntry<String, int>? hotspot) {
    if (hotspot == null) return 'N/A';
    return '${hotspot.key} (${hotspot.value})';
  }

  Widget _metricChip(
    String label,
    String value, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF173253) : const Color(0xFF0E1A33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFF5D91C6) : const Color(0xFF26456F),
        ),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: const Color(0xFFCAE1FF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) {
      return chip;
    }
    return GestureDetector(onTap: onTap, child: chip);
  }

  Widget _textInput({
    required String label,
    required TextEditingController controller,
    required String hintText,
    double width = 210,
    VoidCallback? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: (_) {
          setState(() {});
          (onChanged ?? _notifyScenarioChanged)();
        },
        style: GoogleFonts.inter(
          color: const Color(0xFFE5F1FF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          isDense: true,
          labelStyle: GoogleFonts.inter(
            color: const Color(0xFF9FB6D5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF5E7598),
            fontSize: 11,
          ),
          filled: true,
          fillColor: const Color(0xFF0E1A33),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF26456F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF26456F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5DA3D5)),
          ),
        ),
      ),
    );
  }

  Widget _trendChart(List<IntakeRunSummary> runs) {
    if (runs.length < 2) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      height: 88,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A33),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend View',
            style: GoogleFonts.inter(
              color: const Color(0xFFAFCAE9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _BenchmarkTrendPainter(runs: runs.reversed.toList()),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selector({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A33),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: const Color(0xFF081326),
          style: GoogleFonts.inter(
            color: const Color(0xFFE5F1FF),
            fontSize: 12,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option,
                  child: Text('$label: $option'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _detailCard({
    required DecisionCreated decision,
    required ExecutionCompleted? executed,
    required ExecutionDenied? denied,
    required List<ResponseArrived> responses,
    required IncidentClosed? closure,
  }) {
    final sortedResponses = [...responses]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF26456F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Decision Trace'),
          _traceLine(
            'Decision created',
            decision.occurredAt,
            'SEQ ${decision.sequence}',
          ),
          if (denied != null)
            _traceLine(
              'Execution denied',
              denied.occurredAt,
              '${denied.operatorId} • ${denied.reason}',
            ),
          if (executed != null)
            _traceLine(
              executed.success ? 'Execution completed' : 'Execution failed',
              executed.occurredAt,
              'SEQ ${executed.sequence}',
            ),
          const SizedBox(height: 10),
          _sectionTitle('Response Trace'),
          if (sortedResponses.isEmpty)
            _muted('No response arrival events yet.')
          else
            ...sortedResponses.map(
              (response) => _traceLine(
                'Guard ${response.guardId} arrived',
                response.occurredAt,
                'SEQ ${response.sequence}',
              ),
            ),
          const SizedBox(height: 10),
          _sectionTitle('Closure Outcome'),
          if (closure == null)
            _muted('Incident not closed.')
          else
            _traceLine(
              'Incident closed (${closure.resolutionType})',
              closure.occurredAt,
              'SEQ ${closure.sequence}',
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.rajdhani(
        color: const Color(0xFFB8D3F4),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _traceLine(String label, DateTime whenUtc, String detail) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label • ${whenUtc.toIso8601String()} • $detail',
        style: GoogleFonts.inter(
          color: const Color(0xFF9AB3D4),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _muted(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(color: const Color(0xFF7F97B8), fontSize: 12),
      ),
    );
  }

  Widget _queueMetaPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BenchmarkTrendPainter extends CustomPainter {
  final List<IntakeRunSummary> runs;

  const _BenchmarkTrendPainter({required this.runs});

  @override
  void paint(Canvas canvas, Size size) {
    if (runs.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final throughputValues = runs.map((run) => run.throughput).toList();
    final verifyValues = runs.map((run) => run.verifyMs.toDouble()).toList();

    final throughputPaint = Paint()
      ..color = const Color(0xFF64D2FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final verifyPaint = Paint()
      ..color = const Color(0xFFFFC36B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = const Color(0xFF2A3F61)
      ..strokeWidth = 1;

    for (int i = 1; i <= 2; i++) {
      final y = (size.height / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawSeries(canvas, size, throughputValues, throughputPaint);
    _drawSeries(canvas, size, verifyValues, verifyPaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = throughputPaint.color;
    final lastThroughputPoint = _pointForIndex(
      size,
      throughputValues,
      throughputValues.length - 1,
    );
    canvas.drawCircle(lastThroughputPoint, 3, dotPaint);

    dotPaint.color = verifyPaint.color;
    final lastVerifyPoint = _pointForIndex(
      size,
      verifyValues,
      verifyValues.length - 1,
    );
    canvas.drawCircle(lastVerifyPoint, 3, dotPaint);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, Paint paint) {
    if (values.length < 2) return;
    final path = Path()
      ..moveTo(
        _pointForIndex(size, values, 0).dx,
        _pointForIndex(size, values, 0).dy,
      );
    for (int i = 1; i < values.length; i++) {
      final point = _pointForIndex(size, values, i);
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _pointForIndex(Size size, List<double> values, int index) {
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : (maxValue - minValue);
    final dx = values.length == 1
        ? 0.0
        : (size.width * index) / (values.length - 1);
    final normalized = (values[index] - minValue) / span;
    final dy = size.height - (normalized * size.height);
    return Offset(dx, dy.clamp(0.0, size.height));
  }

  @override
  bool shouldRepaint(covariant _BenchmarkTrendPainter oldDelegate) {
    return oldDelegate.runs != runs;
  }
}

extension on Iterable<IntakeRunSummary> {
  IntakeRunSummary? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
