part of 'dispatch_page.dart';

extension _DispatchPagePresetImport on _DispatchPageState {
  Future<bool?> _confirmImportFilterPreset(
    DispatchBenchmarkFilterPreset preset, {
    DispatchBenchmarkFilterPreset? existing,
  }) {
    final isReplace = existing != null;
    final changeDetails = isReplace
        ? _filterPresetChangeDetails(existing, preset)
        : const <String>[];
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            isReplace ? 'Replace Filter Preset' : 'Import Filter Preset',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _snapshotInspectLine('View', preset.name),
                _snapshotInspectLine(
                  'Mode',
                  isReplace ? 'Replace existing view' : 'New imported view',
                ),
                _snapshotInspectLine('Revision', 'Rev ${preset.revision}'),
                _snapshotInspectLine('Sort', _sortFromName(preset.sort).label),
                _snapshotInspectLine('History', preset.historyLimit.toString()),
                if (isReplace)
                  _snapshotInspectLine('Replacing', 'Rev ${existing.revision}'),
                if (isReplace && changeDetails.isEmpty)
                  _snapshotInspectLine('Changes', 'none'),
                if (changeDetails.isNotEmpty) ...[
                  _snapshotInspectLine('Changes', changeDetails.first),
                  for (final detail in changeDetails.skip(1))
                    _snapshotInspectContinuationLine('- $detail'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                isReplace ? 'Replace' : 'Import',
                style: GoogleFonts.inter(color: const Color(0xFFD9F6EE)),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _filterPresetChangeDetails(
    DispatchBenchmarkFilterPreset existing,
    DispatchBenchmarkFilterPreset next,
  ) {
    final changes = <String>[];
    if (existing.showCancelledRuns != next.showCancelledRuns) {
      changes.add(
        'cancelled: ${existing.showCancelledRuns ? 'on' : 'off'} -> '
        '${next.showCancelledRuns ? 'on' : 'off'}',
      );
    }
    final existingStatuses = existing.statusFilters.toList(growable: false)
      ..sort();
    final nextStatuses = next.statusFilters.toList(growable: false)..sort();
    if (!_listEquals(existingStatuses, nextStatuses)) {
      changes.add(
        'status: ${_formatStatusFilters(existingStatuses)} -> '
        '${_formatStatusFilters(nextStatuses)}',
      );
    }
    if (existing.scenarioFilter != next.scenarioFilter) {
      changes.add(
        'scenario: ${_formatFilterValue(existing.scenarioFilter)} -> '
        '${_formatFilterValue(next.scenarioFilter)}',
      );
    }
    if (existing.tagFilter != next.tagFilter) {
      changes.add(
        'tag: ${_formatFilterValue(existing.tagFilter)} -> '
        '${_formatFilterValue(next.tagFilter)}',
      );
    }
    if (existing.noteFilter != next.noteFilter) {
      changes.add(
        'note: ${_formatFilterValue(existing.noteFilter)} -> '
        '${_formatFilterValue(next.noteFilter)}',
      );
    }
    if (existing.sort != next.sort) {
      changes.add(
        'sort: ${_sortFromName(existing.sort).label} -> '
        '${_sortFromName(next.sort).label}',
      );
    }
    if (existing.historyLimit != next.historyLimit) {
      changes.add('history: ${existing.historyLimit} -> ${next.historyLimit}');
    }
    return changes;
  }

  String _formatStatusFilters(List<String> statuses) {
    return statuses.isEmpty ? 'all' : statuses.join('|');
  }

  String _formatFilterValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'all' : trimmed;
  }
}
