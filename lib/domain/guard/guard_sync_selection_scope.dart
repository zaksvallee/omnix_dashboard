String guardSyncSelectionScopeKey({
  required String historyFilter,
  required String operationModeFilter,
  String? facadeId,
}) {
  final history = historyFilter.trim();
  final mode = operationModeFilter.trim();
  final facade = (facadeId ?? '').trim();
  if (facade.isEmpty) {
    return '$history|$mode|all_facades';
  }
  return '$history|$mode|$facade';
}

const _knownGuardSyncHistoryFilters = {'queued', 'synced', 'failed', 'all'};
const _knownGuardSyncModeFilters = {'all', 'live', 'stub', 'unknown'};

String? normalizeGuardSyncSelectionScopeKey(String raw) {
  final parts = raw.split('|');
  if (parts.isEmpty) return null;
  final history = parts.first.trim();
  if (history.isEmpty) return null;
  final normalizedHistory = _knownGuardSyncHistoryFilters.contains(history)
      ? history
      : 'all';
  final requestedMode = parts.length > 1 ? parts[1].trim() : '';
  final mode = _knownGuardSyncModeFilters.contains(requestedMode)
      ? requestedMode
      : 'all';
  final facade = parts.length > 2 && parts[2].trim().isNotEmpty
      ? parts[2].trim()
      : 'all_facades';
  return '$normalizedHistory|$mode|$facade';
}

Map<String, String> migrateLegacyGuardSyncSelectionScopes(
  Map<String, String> raw,
) {
  if (raw.isEmpty) return const {};
  final migrated = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key.trim();
    final value = entry.value.trim();
    if (key.isEmpty || value.isEmpty) {
      continue;
    }
    if (key.contains('|')) {
      final normalized = normalizeGuardSyncSelectionScopeKey(key);
      if (normalized == null) {
        continue;
      }
      migrated.putIfAbsent(normalized, () => value);
      continue;
    }
    migrated.putIfAbsent('$key|all|all_facades', () => value);
  }
  return migrated;
}

bool guardSyncSelectionScopesEqual(
  Map<String, String> a,
  Map<String, String> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

Map<String, String> setGuardSyncSelectionForScope({
  required Map<String, String> current,
  required String scopeKey,
  String? operationId,
}) {
  final normalizedScope = normalizeGuardSyncSelectionScopeKey(scopeKey);
  if (normalizedScope == null || normalizedScope.isEmpty) {
    return Map<String, String>.from(current);
  }
  final normalizedOperationId = operationId?.trim() ?? '';
  final next = Map<String, String>.from(current);
  if (normalizedOperationId.isEmpty) {
    next.remove(normalizedScope);
    return next;
  }
  next[normalizedScope] = normalizedOperationId;
  return next;
}

Map<String, String> pruneGuardSyncSelectionScopesByOperationIds({
  required Map<String, String> current,
  required Set<String> knownOperationIds,
}) {
  if (current.isEmpty) {
    return const {};
  }
  final normalizedKnownIds = knownOperationIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (normalizedKnownIds.isEmpty) {
    return const {};
  }
  final pruned = <String, String>{};
  for (final entry in current.entries) {
    final scope = entry.key.trim();
    final operationId = entry.value.trim();
    if (scope.isEmpty || operationId.isEmpty) {
      continue;
    }
    if (normalizedKnownIds.contains(operationId)) {
      pruned[scope] = operationId;
    }
  }
  return pruned;
}

bool shouldPruneGuardSyncSelections({
  required int fetchedOperationCount,
  required int fetchLimit,
  required bool hasKnownOperationIds,
}) {
  if (!hasKnownOperationIds) {
    return false;
  }
  if (fetchLimit <= 0) {
    return true;
  }
  return fetchedOperationCount < fetchLimit;
}

Map<String, String> clearGuardSyncSelectionIfScopeOperationMissing({
  required Map<String, String> current,
  required String scopeKey,
  required Set<String> visibleOperationIds,
}) {
  final normalizedScope = normalizeGuardSyncSelectionScopeKey(scopeKey);
  if (normalizedScope == null || normalizedScope.isEmpty) {
    return Map<String, String>.from(current);
  }
  final currentOperationId = (current[normalizedScope] ?? '').trim();
  if (currentOperationId.isEmpty) {
    return Map<String, String>.from(current);
  }
  final normalizedVisibleIds = visibleOperationIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (normalizedVisibleIds.contains(currentOperationId)) {
    return Map<String, String>.from(current);
  }
  final next = Map<String, String>.from(current);
  next.remove(normalizedScope);
  return next;
}

Map<String, String> applyGuardSyncSelectionMaintenance({
  required Map<String, String> current,
  required Set<String> knownOperationIds,
  required int fetchedOperationCount,
  required int fetchLimit,
  required String activeScopeKey,
  required Set<String> activeScopeVisibleOperationIds,
}) {
  var next = Map<String, String>.from(current);
  if (shouldPruneGuardSyncSelections(
    fetchedOperationCount: fetchedOperationCount,
    fetchLimit: fetchLimit,
    hasKnownOperationIds: knownOperationIds.isNotEmpty,
  )) {
    next = pruneGuardSyncSelectionScopesByOperationIds(
      current: next,
      knownOperationIds: knownOperationIds,
    );
  }
  next = clearGuardSyncSelectionIfScopeOperationMissing(
    current: next,
    scopeKey: activeScopeKey,
    visibleOperationIds: activeScopeVisibleOperationIds,
  );
  return next;
}
