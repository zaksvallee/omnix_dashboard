part of 'dispatch_page.dart';

enum _SnapshotImportMode { merge, replace }

class _SnapshotImportRequest {
  final _SnapshotImportMode mode;
  final Set<String> selectedPresetNames;
  final bool importDraftMetadata;
  final bool importSavedViews;

  const _SnapshotImportRequest({
    required this.mode,
    required this.selectedPresetNames,
    required this.importDraftMetadata,
    required this.importSavedViews,
  });
}

class _SnapshotInspectViewModel {
  final List<String> collidingPresetNames;
  final List<String> collisionDiffLines;
  final List<String> incomingOnlyPresetNames;
  final int collisions;
  final int unchangedCollisions;
  final int mergedViewCount;
  final bool hasSelectedSavedViews;
  final String selectedViewsValue;
  final String importScopeValue;
  final String? mergeActionLabel;
  final String replaceActionLabel;
  final bool canApplyImport;
  final String draftMetadataToggleLabel;
  final String savedViewsToggleLabel;

  const _SnapshotInspectViewModel({
    required this.collidingPresetNames,
    required this.collisionDiffLines,
    required this.incomingOnlyPresetNames,
    required this.collisions,
    required this.unchangedCollisions,
    required this.mergedViewCount,
    required this.hasSelectedSavedViews,
    required this.selectedViewsValue,
    required this.importScopeValue,
    required this.mergeActionLabel,
    required this.replaceActionLabel,
    required this.canApplyImport,
    required this.draftMetadataToggleLabel,
    required this.savedViewsToggleLabel,
  });
}

class _SnapshotInspectController {
  final DispatchSnapshot snapshot;
  final Set<String> selectedPresetNames;

  bool importDraftMetadata = true;
  bool importSavedViews = true;

  _SnapshotInspectController({
    required this.snapshot,
    required Set<String> initialSelectedPresetNames,
  }) : selectedPresetNames = Set<String>.from(initialSelectedPresetNames);

  DispatchSnapshot importSnapshot(
    DispatchSnapshot Function(DispatchSnapshot, Set<String>?) selectPresets,
  ) {
    return selectPresets(
      snapshot,
      importSavedViews ? selectedPresetNames : const <String>{},
    );
  }

  void setImportDraftMetadata(bool? selected) {
    importDraftMetadata = selected ?? false;
  }

  void setImportSavedViews(bool? selected) {
    importSavedViews = selected ?? false;
  }

  void selectAllSavedViews(Iterable<String> names) {
    selectedPresetNames
      ..clear()
      ..addAll(names);
  }

  void clearSavedViews() {
    selectedPresetNames.clear();
  }

  void setSavedViewSelected(String presetName, bool? selected) {
    if (selected ?? false) {
      selectedPresetNames.add(presetName);
    } else {
      selectedPresetNames.remove(presetName);
    }
  }

  _SnapshotImportRequest buildRequest(_SnapshotImportMode mode) {
    return _SnapshotImportRequest(
      mode: mode,
      selectedPresetNames: Set<String>.from(selectedPresetNames),
      importDraftMetadata: importDraftMetadata,
      importSavedViews: importSavedViews,
    );
  }
}

extension _DispatchPageSnapshotInspector on _DispatchPageState {
  Future<_SnapshotImportRequest?> _confirmSnapshotImport(
    DispatchSnapshot snapshot,
  ) {
    final allIncomingPresetNames = _snapshotIncomingPresetNames(snapshot);
    final canSelectPresetViews = snapshot.filterPresets.isNotEmpty;
    final controller = _SnapshotInspectController(
      snapshot: snapshot,
      initialSelectedPresetNames: snapshot.filterPresets
          .map((preset) => preset.name)
          .toSet(),
    );
    return showDialog<_SnapshotImportRequest>(
      context: context,
      builder: (context) {
        final scenario = snapshot.scenarioLabel.isEmpty
            ? 'N/A'
            : snapshot.scenarioLabel;
        final tags = snapshot.tags.isEmpty ? 'N/A' : snapshot.tags.join(', ');
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final importSnapshot = controller.importSnapshot(
              _snapshotWithSelectedPresets,
            );
            final selectedIncomingPresetNames = _snapshotIncomingPresetNames(
              importSnapshot,
            );
            final viewModel = _buildSnapshotInspectViewModel(
              importSnapshot: importSnapshot,
              selectedIncomingPresetNames: selectedIncomingPresetNames,
              importDraftMetadata: controller.importDraftMetadata,
              importSavedViews: controller.importSavedViews,
            );

            return AlertDialog(
              backgroundColor: const Color(0xFF0A1830),
              title: Text(
                'Inspect Snapshot',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5F1FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: _buildSnapshotInspectContent(
                    snapshot: snapshot,
                    scenario: scenario,
                    tags: tags,
                    draftMetadataToggleLabel:
                        viewModel.draftMetadataToggleLabel,
                    savedViewsToggleLabel: viewModel.savedViewsToggleLabel,
                    importDraftMetadata: controller.importDraftMetadata,
                    importSavedViews: controller.importSavedViews,
                    canSelectPresetViews: canSelectPresetViews,
                    importScopeValue: viewModel.importScopeValue,
                    allIncomingPresetNames: allIncomingPresetNames,
                    selectedIncomingPresetNames: selectedIncomingPresetNames,
                    selectedViewsValue: viewModel.selectedViewsValue,
                    selectedPresetNames: controller.selectedPresetNames,
                    collisions: viewModel.collisions,
                    collidingPresetNames: viewModel.collidingPresetNames,
                    unchangedCollisions: viewModel.unchangedCollisions,
                    collisionDiffLines: viewModel.collisionDiffLines,
                    incomingOnlyPresetNames: viewModel.incomingOnlyPresetNames,
                    mergedViewCount: viewModel.mergedViewCount,
                    onImportDraftMetadataChanged: (selected) {
                      setDialogState(() {
                        controller.setImportDraftMetadata(selected);
                      });
                    },
                    onImportSavedViewsChanged: canSelectPresetViews
                        ? (selected) {
                            setDialogState(() {
                              controller.setImportSavedViews(selected);
                            });
                          }
                        : null,
                    onSelectAllSavedViews:
                        selectedIncomingPresetNames.length ==
                            snapshot.filterPresets.length
                        ? null
                        : () {
                            setDialogState(() {
                              controller.selectAllSavedViews(
                                allIncomingPresetNames,
                              );
                            });
                          },
                    onClearAllSavedViews: selectedIncomingPresetNames.isEmpty
                        ? null
                        : () {
                            setDialogState(() {
                              controller.clearSavedViews();
                            });
                          },
                    onSavedViewChanged: (presetName, selected) {
                      setDialogState(() {
                        controller.setSavedViewSelected(presetName, selected);
                      });
                    },
                  ),
                ),
              ),
              actions: _buildSnapshotInspectActions(
                canSelectPresetViews: canSelectPresetViews,
                mergeActionLabel: viewModel.mergeActionLabel,
                replaceActionLabel: viewModel.replaceActionLabel,
                onMergePressed: !viewModel.canApplyImport
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(controller.buildRequest(_SnapshotImportMode.merge)),
                onReplacePressed: !viewModel.canApplyImport
                    ? null
                    : () => Navigator.of(context).pop(
                        controller.buildRequest(_SnapshotImportMode.replace),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  _SnapshotInspectViewModel _buildSnapshotInspectViewModel({
    required DispatchSnapshot importSnapshot,
    required List<String> selectedIncomingPresetNames,
    required bool importDraftMetadata,
    required bool importSavedViews,
  }) {
    final collidingPresetNames = _snapshotCollidingPresetNames(importSnapshot);
    final collisionDiffLines = _snapshotCollisionDiffLines(importSnapshot);
    final incomingOnlyPresetNames = _snapshotIncomingOnlyPresetNames(
      importSnapshot,
    );
    final collisions = collidingPresetNames.length;
    final unchangedCollisions = _snapshotUnchangedCollisions(importSnapshot);
    final mergedViewCount = _mergeSnapshotFilterPresets(importSnapshot).length;
    final hasSelectedSavedViews = selectedIncomingPresetNames.isNotEmpty;
    final selectedViewsValue = selectedIncomingPresetNames.isEmpty
        ? '0 (none)'
        : '${selectedIncomingPresetNames.length} (${selectedIncomingPresetNames.join(', ')})';
    final importScopeValue = importDraftMetadata && importSavedViews
        ? (hasSelectedSavedViews
              ? 'Combined import'
              : 'Draft metadata only (saved view selection required)')
        : importDraftMetadata
        ? 'Draft metadata only'
        : importSavedViews
        ? (hasSelectedSavedViews
              ? 'Saved views only'
              : 'Saved views only (selection required)')
        : 'Nothing selected';
    final mergeActionLabel = importSavedViews && collisions > 0
        ? (importDraftMetadata
              ? 'Merge Views & Apply All'
              : 'Merge Saved Views')
        : null;
    final replaceActionLabel = importDraftMetadata && importSavedViews
        ? (collisions > 0 ? 'Replace Views & Apply All' : 'Apply All')
        : importDraftMetadata
        ? 'Apply Metadata Only'
        : importSavedViews
        ? (collisions > 0 ? 'Replace Saved Views' : 'Apply Saved Views')
        : 'Apply';
    final canApplyImport =
        importDraftMetadata || (importSavedViews && hasSelectedSavedViews);
    final draftMetadataToggleLabel =
        'Import Draft Metadata (${importDraftMetadata ? 'on' : 'off'})';
    final savedViewsToggleLabel =
        'Import Saved Views (${selectedIncomingPresetNames.length} selected)';
    return _SnapshotInspectViewModel(
      collidingPresetNames: collidingPresetNames,
      collisionDiffLines: collisionDiffLines,
      incomingOnlyPresetNames: incomingOnlyPresetNames,
      collisions: collisions,
      unchangedCollisions: unchangedCollisions,
      mergedViewCount: mergedViewCount,
      hasSelectedSavedViews: hasSelectedSavedViews,
      selectedViewsValue: selectedViewsValue,
      importScopeValue: importScopeValue,
      mergeActionLabel: mergeActionLabel,
      replaceActionLabel: replaceActionLabel,
      canApplyImport: canApplyImport,
      draftMetadataToggleLabel: draftMetadataToggleLabel,
      savedViewsToggleLabel: savedViewsToggleLabel,
    );
  }

  Widget _buildSnapshotInspectContent({
    required DispatchSnapshot snapshot,
    required String scenario,
    required String tags,
    required String draftMetadataToggleLabel,
    required String savedViewsToggleLabel,
    required bool importDraftMetadata,
    required bool importSavedViews,
    required bool canSelectPresetViews,
    required String importScopeValue,
    required List<String> allIncomingPresetNames,
    required List<String> selectedIncomingPresetNames,
    required String selectedViewsValue,
    required Set<String> selectedPresetNames,
    required int collisions,
    required List<String> collidingPresetNames,
    required int unchangedCollisions,
    required List<String> collisionDiffLines,
    required List<String> incomingOnlyPresetNames,
    required int mergedViewCount,
    required ValueChanged<bool?> onImportDraftMetadataChanged,
    required ValueChanged<bool?>? onImportSavedViewsChanged,
    required VoidCallback? onSelectAllSavedViews,
    required VoidCallback? onClearAllSavedViews,
    required void Function(String presetName, bool? selected)
    onSavedViewChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _snapshotInspectLine('Version', 'v${snapshot.version}'),
        _snapshotInspectLine('Scenario', scenario),
        _snapshotInspectLine('Tags', tags),
        _snapshotInspectToggle(
          label: draftMetadataToggleLabel,
          value: importDraftMetadata,
          onChanged: onImportDraftMetadataChanged,
        ),
        _snapshotInspectToggle(
          label: savedViewsToggleLabel,
          value: importSavedViews,
          onChanged: onImportSavedViewsChanged,
        ),
        _snapshotInspectLine('Import Scope', importScopeValue),
        _snapshotInspectLine(
          'Saved Views',
          snapshot.filterPresets.length.toString(),
        ),
        if (allIncomingPresetNames.isNotEmpty)
          _snapshotInspectLine(
            'Incoming Names',
            allIncomingPresetNames.join(', '),
          ),
        if (canSelectPresetViews && importSavedViews) ...[
          _snapshotInspectLine('Selected Views', selectedViewsValue),
          if (selectedIncomingPresetNames.isEmpty)
            _snapshotInspectLine(
              'Selection',
              'Select at least one incoming saved view to import.',
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _snapshotInspectAction(
                  label: 'Select all',
                  color: const Color(0xFF56B6FF),
                  onPressed: onSelectAllSavedViews,
                ),
                _snapshotInspectAction(
                  label: 'Clear all',
                  color: const Color(0xFF8EA4C2),
                  onPressed: onClearAllSavedViews,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final preset in snapshot.filterPresets)
            _snapshotInspectToggle(
              label: preset.name,
              value: selectedPresetNames.contains(preset.name),
              onChanged: (selected) =>
                  onSavedViewChanged(preset.name, selected),
            ),
        ],
        if (importSavedViews && collisions > 0)
          _snapshotInspectLine('View Collisions', collisions.toString()),
        if (importSavedViews && collidingPresetNames.isNotEmpty)
          _snapshotInspectLine(
            'Collision Names',
            collidingPresetNames.join(', '),
          ),
        if (importSavedViews && unchangedCollisions > 0)
          _snapshotInspectLine(
            'Unchanged Collisions',
            unchangedCollisions.toString(),
          ),
        if (importSavedViews && collisionDiffLines.isNotEmpty) ...[
          _snapshotInspectLine('Collision Changes', collisionDiffLines.first),
          for (final line in collisionDiffLines.skip(1))
            _snapshotInspectContinuationLine(line),
        ],
        if (importSavedViews && incomingOnlyPresetNames.isNotEmpty)
          _snapshotInspectLine(
            'Incoming Only',
            '${incomingOnlyPresetNames.length} (${incomingOnlyPresetNames.join(', ')})',
          ),
        if (canSelectPresetViews && importSavedViews && collisions > 0)
          _snapshotInspectLine('Merge Result', '$mergedViewCount saved views'),
        _snapshotInspectLine(
          'Telemetry Runs',
          snapshot.telemetry.runs.toString(),
        ),
        _snapshotInspectLine(
          'Profile',
          '${snapshot.profile.feeds} feeds / ${snapshot.profile.bursts} bursts',
        ),
      ],
    );
  }

  List<Widget> _buildSnapshotInspectActions({
    required bool canSelectPresetViews,
    required String? mergeActionLabel,
    required String replaceActionLabel,
    required VoidCallback? onMergePressed,
    required VoidCallback? onReplacePressed,
  }) {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          'Cancel',
          style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
        ),
      ),
      if (canSelectPresetViews && mergeActionLabel != null)
        TextButton(
          onPressed: onMergePressed,
          child: Text(
            mergeActionLabel,
            style: GoogleFonts.inter(color: const Color(0xFFB9E7D2)),
          ),
        ),
      TextButton(
        onPressed: onReplacePressed,
        child: Text(
          replaceActionLabel,
          style: GoogleFonts.inter(color: const Color(0xFFBFD8FF)),
        ),
      ),
    ];
  }

  Widget _snapshotInspectToggle({
    required String label,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF56B6FF),
      checkColor: const Color(0xFF04101F),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFE5F1FF),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _snapshotInspectAction({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
