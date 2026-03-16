import 'dart:convert';

import 'listener_alarm_scope_mapping_service.dart';

class ListenerAlarmScopeRegistryRepository {
  final List<ListenerAlarmScopeMappingEntry> _entries;

  ListenerAlarmScopeRegistryRepository({
    List<ListenerAlarmScopeMappingEntry> seedEntries = const [],
  }) : _entries = [...seedEntries];

  List<ListenerAlarmScopeMappingEntry> allEntries() {
    return [..._entries];
  }

  List<ListenerAlarmScopeMappingEntry> entriesForAccount(String accountNumber) {
    final normalized = accountNumber.trim();
    return _entries
        .where((entry) => entry.accountNumber.trim() == normalized)
        .toList(growable: false);
  }

  void replaceAll(List<ListenerAlarmScopeMappingEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
  }

  void upsert(ListenerAlarmScopeMappingEntry entry) {
    final index = _entries.indexWhere(
      (candidate) => _bindingKey(candidate) == _bindingKey(entry),
    );
    if (index == -1) {
      _entries.add(entry);
      return;
    }
    _entries[index] = entry;
  }

  bool remove({
    required String accountNumber,
    String partition = '',
    String zone = '',
  }) {
    final key = _bindingKey(
      ListenerAlarmScopeMappingEntry(
        accountNumber: accountNumber,
        partition: partition,
        zone: zone,
        siteId: '',
        siteName: '',
        clientId: '',
        clientName: '',
        regionId: '',
      ),
    );
    final beforeCount = _entries.length;
    _entries.removeWhere((entry) => _bindingKey(entry) == key);
    return _entries.length != beforeCount;
  }

  String exportJson() {
    final rows = _entries.map((entry) => entry.toJson()).toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(rows);
  }

  void importJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Alarm scope registry JSON must be a list.');
    }
    final entries = decoded
        .whereType<Map>()
        .map(
          (entry) => ListenerAlarmScopeMappingEntry.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value as Object?)),
          ),
        )
        .toList(growable: false);
    replaceAll(entries);
  }

  String _bindingKey(ListenerAlarmScopeMappingEntry entry) {
    return [
      entry.accountNumber.trim(),
      entry.partition.trim(),
      entry.zone.trim(),
    ].join('|');
  }
}
