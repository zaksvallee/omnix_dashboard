part of 'dispatch_page.dart';

extension _DispatchPageFilterPresets on _DispatchPageState {
  Future<void> _saveCurrentFilterPreset() async {
    final suggestedName = _activeFilterPresetName ?? _activeScenarioLabel;
    final name = await _promptForPresetName(
      title: 'Save Filter Preset',
      actionLabel: 'Save',
      initialValue: suggestedName == 'N/A' ? '' : suggestedName,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    final existing = _findFilterPresetByName(trimmed);
    final nextPreset = _buildFilterPresetSnapshot(
      name: trimmed,
      revision: existing?.revision ?? 1,
    );
    if (existing != null) {
      final confirmed = await _confirmImportFilterPreset(
        nextPreset,
        existing: existing,
      );
      if (confirmed != true) return;
    }
    _upsertFilterPreset(nextPreset, applyPreset: true);
    if (!mounted) return;
    _showSnack(
      existing == null ? 'Filter preset saved' : 'Filter preset replaced',
    );
  }

  Future<void> _renameActiveFilterPreset() async {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return;

    final nextName = await _promptForPresetName(
      title: 'Rename Filter Preset',
      actionLabel: 'Rename',
      initialValue: active.name,
    );
    final trimmed = nextName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == active.name) return;
    if (_findFilterPresetByName(trimmed) != null) {
      _showSnack('A view named "$trimmed" already exists');
      return;
    }

    final renamed = DispatchBenchmarkFilterPreset(
      name: trimmed,
      revision: active.revision,
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      showCancelledRuns: active.showCancelledRuns,
      statusFilters: active.statusFilters,
      scenarioFilter: active.scenarioFilter,
      tagFilter: active.tagFilter,
      noteFilter: active.noteFilter,
      sort: active.sort,
      historyLimit: active.historyLimit,
    );
    _replaceFilterPreset(active.name, renamed, applyPreset: true);
    if (!mounted) return;
    _showSnack('Filter preset renamed');
  }

  void _overwriteActiveFilterPreset() {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return;
    final nextPreset = _buildFilterPresetSnapshot(
      name: active.name,
      revision: active.revision + 1,
    );
    _upsertFilterPreset(nextPreset, applyPreset: true);
    _showSnack('Filter preset updated');
  }

  void _applyFilterPreset(DispatchBenchmarkFilterPreset? preset) {
    if (preset == null) {
      _updateViewState(() => _activeFilterPresetName = null);
      return;
    }
    _applyFilterPresetState(preset);
  }

  Future<void> _deleteActiveFilterPreset() async {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return;
    final confirmed = await _confirmDeleteFilterPreset(active.name);
    if (confirmed != true) return;

    final nextPresets = _savedFilterPresets
        .where((preset) => preset.name != active.name)
        .toList(growable: false);
    _updateViewState(() {
      _savedFilterPresets = nextPresets;
      _activeFilterPresetName = null;
    });
    widget.onFilterPresetsChanged?.call(nextPresets);
    if (!mounted) return;
    _showSnack('Filter preset deleted');
  }

  Future<void> _copyActiveFilterPresetJson() async {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return;
    final payload = _DispatchPageState._clipboard.exportFilterPresetJson(
      active,
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showSnack('View JSON copied');
  }

  Future<void> _importFilterPresetJson() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      _showSnack('Clipboard is empty');
      return;
    }
    await _importFilterPresetPayload(raw, sourceLabel: 'clipboard');
  }

  Future<void> _downloadActiveFilterPresetFile() async {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return;
    if (!_DispatchPageState._snapshotFiles.supported) {
      _showSnack('View file export is only available on web');
      return;
    }
    await _DispatchPageState._snapshotFiles.downloadJsonFile(
      filename: _filterPresetFilename(active.name),
      contents: _DispatchPageState._clipboard.exportFilterPresetJson(active),
    );
    if (!mounted) return;
    _showSnack('View file download started');
  }

  Future<void> _loadFilterPresetFile() async {
    if (!_DispatchPageState._snapshotFiles.supported) {
      _showSnack('View file import is only available on web');
      return;
    }
    final raw = await _DispatchPageState._snapshotFiles.pickJsonFile();
    if (raw == null) {
      _showSnack('No view file selected');
      return;
    }
    await _importFilterPresetPayload(raw, sourceLabel: 'file');
  }

  String _filterPresetFilename(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final suffix = normalized.isEmpty ? 'dispatch_view' : normalized;
    return 'onyx_view_$suffix.json';
  }

  Future<void> _importFilterPresetPayload(
    String raw, {
    required String sourceLabel,
  }) async {
    try {
      final preset = _DispatchPageState._clipboard.importFilterPresetJson(raw);
      if (preset.name.trim().isEmpty) {
        throw const FormatException('Filter preset name is required');
      }
      final existing = _findFilterPresetByName(preset.name);
      final confirmed = await _confirmImportFilterPreset(
        preset,
        existing: existing,
      );
      if (confirmed != true) return;
      _upsertFilterPreset(preset, applyPreset: true);
      if (!mounted) return;
      _showSnack(
        existing == null
            ? 'Filter preset imported from $sourceLabel'
            : 'Filter preset replaced from $sourceLabel',
      );
    } on FormatException catch (error) {
      _showSnack(error.message);
    }
  }

  DispatchBenchmarkFilterPreset get _currentFilterPresetSnapshot {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    return _buildFilterPresetSnapshot(
      name: active?.name ?? '',
      revision: active?.revision ?? 1,
      updatedAtUtc: active?.updatedAtUtc,
    );
  }

  bool get _isActiveFilterPresetDirty {
    final active = _findFilterPresetByName(_activeFilterPresetName);
    if (active == null) return false;
    return !_sameFilterPreset(active, _currentFilterPresetSnapshot);
  }

  bool _sameFilterPreset(
    DispatchBenchmarkFilterPreset left,
    DispatchBenchmarkFilterPreset right,
  ) {
    final leftStatuses = left.statusFilters.toList(growable: false)..sort();
    final rightStatuses = right.statusFilters.toList(growable: false)..sort();
    return left.name == right.name &&
        left.showCancelledRuns == right.showCancelledRuns &&
        _listEquals(leftStatuses, rightStatuses) &&
        left.scenarioFilter == right.scenarioFilter &&
        left.tagFilter == right.tagFilter &&
        left.noteFilter == right.noteFilter &&
        left.sort == right.sort &&
        left.historyLimit == right.historyLimit;
  }

  bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  DispatchBenchmarkFilterPreset _buildFilterPresetSnapshot({
    required String name,
    required int revision,
    String? updatedAtUtc,
  }) {
    final statuses = _statusFilters.toList(growable: false)..sort();
    return DispatchBenchmarkFilterPreset(
      name: name,
      revision: revision,
      updatedAtUtc: updatedAtUtc ?? DateTime.now().toUtc().toIso8601String(),
      showCancelledRuns: _showCancelledRuns,
      statusFilters: statuses,
      scenarioFilter: _historyScenarioFilter ?? '',
      tagFilter: _historyTagFilter ?? '',
      noteFilter: _historyNoteFilterController.text.trim(),
      sort: _historySort.name,
      historyLimit: _historyLimit,
    );
  }

  void _upsertFilterPreset(
    DispatchBenchmarkFilterPreset preset, {
    required bool applyPreset,
  }) {
    _replaceFilterPreset(preset.name, preset, applyPreset: applyPreset);
  }

  void _replaceFilterPreset(
    String previousName,
    DispatchBenchmarkFilterPreset preset, {
    required bool applyPreset,
  }) {
    final nextPresets = [
      for (final current in _savedFilterPresets)
        if (current.name != previousName && current.name != preset.name)
          current,
      preset,
    ]..sort((a, b) => a.name.compareTo(b.name));

    _updateViewState(() {
      _savedFilterPresets = nextPresets;
      if (applyPreset) {
        _applyFilterPresetFields(preset);
      } else {
        _activeFilterPresetName = preset.name;
      }
    });
    widget.onFilterPresetsChanged?.call(nextPresets);
  }

  void _applyFilterPresetState(DispatchBenchmarkFilterPreset preset) {
    _updateViewState(() => _applyFilterPresetFields(preset));
  }

  void _applyFilterPresetFields(DispatchBenchmarkFilterPreset preset) {
    _activeFilterPresetName = preset.name;
    _showCancelledRuns = preset.showCancelledRuns;
    _statusFilters
      ..clear()
      ..addAll(preset.statusFilters);
    _historyScenarioFilter = _emptyToNull(preset.scenarioFilter);
    _historyTagFilter = _emptyToNull(preset.tagFilter);
    _historyNoteFilterController.text = preset.noteFilter;
    _historySort = _sortFromName(preset.sort);
    _historyLimit = preset.historyLimit;
    _baselineRunLabel = null;
  }
}
