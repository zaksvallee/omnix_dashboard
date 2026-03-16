import 'listener_serial_ingestor.dart';
import 'monitoring_shift_notification_service.dart';

enum ListenerAlarmScopeMatchMode {
  accountPartitionZone,
  accountPartition,
  accountZone,
  accountOnly,
}

class ListenerAlarmScopeMappingEntry {
  final String accountNumber;
  final String partition;
  final String zone;
  final String zoneLabel;
  final String siteId;
  final String siteName;
  final String clientId;
  final String clientName;
  final String regionId;

  const ListenerAlarmScopeMappingEntry({
    required this.accountNumber,
    required this.siteId,
    required this.siteName,
    required this.clientId,
    required this.clientName,
    required this.regionId,
    this.partition = '',
    this.zone = '',
    this.zoneLabel = '',
  });

  Map<String, Object?> toJson() {
    return {
      'account_number': accountNumber,
      'partition': partition,
      'zone': zone,
      'zone_label': zoneLabel,
      'site_id': siteId,
      'site_name': siteName,
      'client_id': clientId,
      'client_name': clientName,
      'region_id': regionId,
    };
  }

  factory ListenerAlarmScopeMappingEntry.fromJson(Map<String, Object?> json) {
    return ListenerAlarmScopeMappingEntry(
      accountNumber: (json['account_number'] ?? '').toString().trim(),
      partition: (json['partition'] ?? '').toString().trim(),
      zone: (json['zone'] ?? '').toString().trim(),
      zoneLabel: (json['zone_label'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      siteName: (json['site_name'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      clientName: (json['client_name'] ?? '').toString().trim(),
      regionId: (json['region_id'] ?? '').toString().trim(),
    );
  }
}

class ListenerAlarmScopeResolution {
  final ListenerSerialEnvelope envelope;
  final ListenerAlarmScopeMappingEntry entry;
  final ListenerAlarmScopeMatchMode matchMode;

  const ListenerAlarmScopeResolution({
    required this.envelope,
    required this.entry,
    required this.matchMode,
  });

  String get resolvedZoneLabel {
    if (entry.zoneLabel.trim().isNotEmpty) {
      return entry.zoneLabel.trim();
    }
    return envelope.zone.trim();
  }

  MonitoringSiteProfile get siteProfile {
    return MonitoringSiteProfile(
      siteName: entry.siteName,
      clientName: entry.clientName,
    );
  }

  ListenerSerialEnvelope remappedEnvelope() {
    return envelope.copyWith(
      siteId: entry.siteId,
      clientId: entry.clientId,
      regionId: entry.regionId,
      metadata: {
        ...envelope.metadata,
        'alarm_scope_match_mode': matchMode.name,
        'alarm_scope_account_number': entry.accountNumber,
        'alarm_scope_site_name': entry.siteName,
        'alarm_scope_client_name': entry.clientName,
        if (entry.partition.trim().isNotEmpty)
          'alarm_scope_partition': entry.partition.trim(),
        if (entry.zone.trim().isNotEmpty) 'alarm_scope_zone': entry.zone.trim(),
        if (resolvedZoneLabel.isNotEmpty) 'alarm_scope_zone_label': resolvedZoneLabel,
      },
    );
  }
}

class ListenerAlarmScopeMappingService {
  const ListenerAlarmScopeMappingService();

  ListenerAlarmScopeResolution? resolve({
    required ListenerSerialEnvelope envelope,
    required List<ListenerAlarmScopeMappingEntry> entries,
  }) {
    final normalizedAccount = envelope.accountNumber.trim();
    final normalizedPartition = envelope.partition.trim();
    final normalizedZone = envelope.zone.trim();

    if (normalizedAccount.isEmpty) {
      return null;
    }

    final accountEntries = entries.where((entry) {
      return entry.accountNumber.trim() == normalizedAccount;
    }).toList(growable: false);

    final exactEntry = _firstMatch(
      accountEntries,
      requiresPartition: true,
      requiresZone: true,
      partition: normalizedPartition,
      zone: normalizedZone,
    );
    if (exactEntry != null) {
      return ListenerAlarmScopeResolution(
        envelope: envelope,
        entry: exactEntry,
        matchMode: ListenerAlarmScopeMatchMode.accountPartitionZone,
      );
    }

    final partitionEntry = _firstMatch(
      accountEntries,
      requiresPartition: true,
      requiresZone: false,
      partition: normalizedPartition,
      zone: normalizedZone,
    );
    if (partitionEntry != null) {
      return ListenerAlarmScopeResolution(
        envelope: envelope,
        entry: partitionEntry,
        matchMode: ListenerAlarmScopeMatchMode.accountPartition,
      );
    }

    final zoneEntry = _firstMatch(
      accountEntries,
      requiresPartition: false,
      requiresZone: true,
      partition: normalizedPartition,
      zone: normalizedZone,
    );
    if (zoneEntry != null) {
      return ListenerAlarmScopeResolution(
        envelope: envelope,
        entry: zoneEntry,
        matchMode: ListenerAlarmScopeMatchMode.accountZone,
      );
    }

    final accountOnlyEntry = _firstMatch(
      accountEntries,
      requiresPartition: false,
      requiresZone: false,
      partition: normalizedPartition,
      zone: normalizedZone,
    );
    if (accountOnlyEntry != null) {
      return ListenerAlarmScopeResolution(
        envelope: envelope,
        entry: accountOnlyEntry,
        matchMode: ListenerAlarmScopeMatchMode.accountOnly,
      );
    }

    return null;
  }

  ListenerAlarmScopeMappingEntry? _firstMatch(
    List<ListenerAlarmScopeMappingEntry> entries, {
    required bool requiresPartition,
    required bool requiresZone,
    required String partition,
    required String zone,
  }) {
    for (final entry in entries) {
      final entryPartition = entry.partition.trim();
      final entryZone = entry.zone.trim();

      if (requiresPartition) {
        if (entryPartition.isEmpty || entryPartition != partition) {
          continue;
        }
      } else if (entryPartition.isNotEmpty) {
        continue;
      }

      if (requiresZone) {
        if (entryZone.isEmpty || entryZone != zone) {
          continue;
        }
      } else if (entryZone.isNotEmpty) {
        continue;
      }

      return entry;
    }
    return null;
  }
}
