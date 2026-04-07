import 'package:supabase_flutter/supabase_flutter.dart';

import '../dvr_http_auth.dart';

enum AdminDirectoryStatus { active, inactive, suspended }

class AdminDirectoryGuardRow {
  final String id;
  final String name;
  final String role;
  final String employeeId;
  final String phone;
  final String email;
  final String psiraNumber;
  final String? psiraExpiry;
  final List<String> certifications;
  final String assignedSite;
  final String shiftPattern;
  final String emergencyContact;
  final AdminDirectoryStatus status;

  const AdminDirectoryGuardRow({
    required this.id,
    required this.name,
    required this.role,
    required this.employeeId,
    required this.phone,
    required this.email,
    required this.psiraNumber,
    this.psiraExpiry,
    required this.certifications,
    required this.assignedSite,
    required this.shiftPattern,
    required this.emergencyContact,
    required this.status,
  });
}

class AdminDirectorySiteRow {
  final String id;
  final String name;
  final String code;
  final String clientId;
  final String address;
  final double lat;
  final double lng;
  final String contactPerson;
  final String contactPhone;
  final String? fskNumber;
  final int geofenceRadiusMeters;
  final String cameraAuthMode;
  final String cameraUsername;
  final String cameraPassword;
  final String cameraBearerToken;
  final AdminDirectoryStatus status;

  const AdminDirectorySiteRow({
    required this.id,
    required this.name,
    required this.code,
    required this.clientId,
    required this.address,
    required this.lat,
    required this.lng,
    required this.contactPerson,
    required this.contactPhone,
    this.fskNumber,
    required this.geofenceRadiusMeters,
    this.cameraAuthMode = 'none',
    this.cameraUsername = '',
    this.cameraPassword = '',
    this.cameraBearerToken = '',
    required this.status,
  });

  DvrHttpAuthConfig get cameraAuthConfig => DvrHttpAuthConfig(
    mode: parseDvrHttpAuthMode(cameraAuthMode),
    username: cameraUsername.trim().isEmpty ? null : cameraUsername.trim(),
    password: cameraPassword.isEmpty ? null : cameraPassword,
    bearerToken: cameraBearerToken.trim().isEmpty
        ? null
        : cameraBearerToken.trim(),
  );
}

class AdminDirectoryClientRow {
  final String id;
  final String name;
  final String code;
  final String contactPerson;
  final String contactEmail;
  final String contactPhone;
  final String slaTier;
  final String contractStart;
  final String contractEnd;
  final int sites;
  final AdminDirectoryStatus status;

  const AdminDirectoryClientRow({
    required this.id,
    required this.name,
    required this.code,
    required this.contactPerson,
    required this.contactEmail,
    required this.contactPhone,
    required this.slaTier,
    required this.contractStart,
    required this.contractEnd,
    required this.sites,
    required this.status,
  });
}

class AdminDirectorySnapshot {
  final List<AdminDirectoryClientRow> clients;
  final List<AdminDirectorySiteRow> sites;
  final List<AdminDirectoryGuardRow> guards;
  final Map<String, int> clientMessagingEndpointCounts;
  final Map<String, int> clientTelegramEndpointCounts;
  final Map<String, int> clientMessagingContactCounts;
  final Map<String, int> clientPartnerEndpointCounts;
  final Map<String, String> clientMessagingLanePreview;
  final Map<String, String> clientTelegramChatcheckStatus;
  final Map<String, String> siteTelegramChatcheckStatus;
  final Map<String, String> clientPartnerLanePreview;
  final Map<String, String> clientPartnerChatcheckStatus;
  final Map<String, List<String>> clientPartnerLaneDetails;
  final Map<String, int> sitePartnerEndpointCounts;
  final Map<String, String> sitePartnerChatcheckStatus;
  final Map<String, List<String>> sitePartnerLaneDetails;

  const AdminDirectorySnapshot({
    required this.clients,
    required this.sites,
    required this.guards,
    required this.clientMessagingEndpointCounts,
    required this.clientTelegramEndpointCounts,
    required this.clientMessagingContactCounts,
    required this.clientPartnerEndpointCounts,
    required this.clientMessagingLanePreview,
    required this.clientTelegramChatcheckStatus,
    required this.siteTelegramChatcheckStatus,
    required this.clientPartnerLanePreview,
    required this.clientPartnerChatcheckStatus,
    required this.clientPartnerLaneDetails,
    required this.sitePartnerEndpointCounts,
    required this.sitePartnerChatcheckStatus,
    required this.sitePartnerLaneDetails,
  });
}

abstract class AdminDirectoryDataSource {
  Future<List<Map<String, dynamic>>> fetchClients();

  Future<List<Map<String, dynamic>>> fetchSites();

  Future<List<Map<String, dynamic>>> fetchEmployees();

  Future<List<Map<String, dynamic>>> fetchAssignments();

  Future<List<Map<String, dynamic>>> fetchMessagingEndpoints();

  Future<List<Map<String, dynamic>>> fetchClientContacts();
}

class SupabaseAdminDirectoryDataSource implements AdminDirectoryDataSource {
  final SupabaseClient supabase;

  const SupabaseAdminDirectoryDataSource(this.supabase);

  @override
  Future<List<Map<String, dynamic>>> fetchClients() async {
    final rows = await supabase.from('clients').select().order('display_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSites() async {
    final rows = await supabase.from('sites').select().order('site_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    final rows = await supabase.from('employees').select().order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAssignments() async {
    final rows = await supabase
        .from('employee_site_assignments')
        .select()
        .eq('assignment_status', 'active');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMessagingEndpoints() async {
    final rows = await supabase
        .from('client_messaging_endpoints')
        .select(
          'client_id, site_id, provider, is_active, display_label, telegram_chat_id, telegram_thread_id, last_delivery_status, last_error',
        );
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClientContacts() async {
    final rows = await supabase
        .from('client_contacts')
        .select('client_id, is_active');
    return List<Map<String, dynamic>>.from(rows);
  }
}

class AdminDirectoryService {
  const AdminDirectoryService();

  Future<AdminDirectorySnapshot> loadDirectory({
    required SupabaseClient supabase,
    String partnerEndpointLabelPrefix = 'PARTNER',
  }) {
    return loadDirectoryFromDataSource(
      dataSource: SupabaseAdminDirectoryDataSource(supabase),
      partnerEndpointLabelPrefix: partnerEndpointLabelPrefix,
    );
  }

  Future<AdminDirectorySnapshot> loadDirectoryFromDataSource({
    required AdminDirectoryDataSource dataSource,
    String partnerEndpointLabelPrefix = 'PARTNER',
  }) async {
    final endpointRowsFuture = _loadOptionalRows(
      dataSource.fetchMessagingEndpoints,
    );
    final contactRowsFuture = _loadOptionalRows(dataSource.fetchClientContacts);

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      dataSource.fetchClients(),
      dataSource.fetchSites(),
      dataSource.fetchEmployees(),
      dataSource.fetchAssignments(),
      endpointRowsFuture,
      contactRowsFuture,
    ]);

    final clientsRows = List<Map<String, dynamic>>.from(results[0] as List);
    final sitesRows = List<Map<String, dynamic>>.from(results[1] as List);
    final employeesRows = List<Map<String, dynamic>>.from(results[2] as List);
    final assignmentsRows = List<Map<String, dynamic>>.from(results[3] as List);
    final endpointRows = List<Map<String, dynamic>>.from(results[4] as List);
    final contactRows = List<Map<String, dynamic>>.from(results[5] as List);

    final siteCounts = <String, int>{};
    for (final site in sitesRows) {
      final clientId = (site['client_id'] ?? '').toString().trim();
      if (clientId.isEmpty) continue;
      siteCounts.update(clientId, (value) => value + 1, ifAbsent: () => 1);
    }

    final endpointCounts = <String, int>{};
    final telegramCounts = <String, int>{};
    final partnerEndpointCounts = <String, int>{};
    final lanePreviewByClient = <String, List<String>>{};
    final partnerLanePreviewByClient = <String, List<String>>{};
    final partnerLaneDetailsByClient = <String, List<String>>{};
    final chatcheckByClient = <String, String>{};
    final chatcheckBySite = <String, String>{};
    final partnerChatcheckByClient = <String, String>{};
    final partnerChatcheckBySite = <String, String>{};
    final partnerEndpointCountsBySite = <String, int>{};
    final partnerLaneDetailsBySite = <String, List<String>>{};

    for (final row in endpointRows) {
      if (row['is_active'] == false) continue;
      final clientId = (row['client_id'] ?? '').toString().trim();
      if (clientId.isEmpty) continue;
      endpointCounts.update(clientId, (value) => value + 1, ifAbsent: () => 1);

      final provider = (row['provider'] ?? '').toString().trim().toLowerCase();
      final label = (row['display_label'] ?? '').toString().trim();
      final isPartner = _isPartnerEndpointLabel(
        label,
        partnerEndpointLabelPrefix,
      );
      final chatId = (row['telegram_chat_id'] ?? '').toString().trim();
      final threadRaw = (row['telegram_thread_id'] ?? '').toString().trim();

      if (provider == 'telegram') {
        if (isPartner) {
          partnerEndpointCounts.update(
            clientId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          final siteId = (row['site_id'] ?? '').toString().trim();
          if (siteId.isNotEmpty) {
            final scopeKey = _siteScopeKey(clientId, siteId);
            partnerEndpointCountsBySite.update(
              scopeKey,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            final detailLine =
                '$label • chat=${chatId.isEmpty ? 'pending' : chatId}'
                '${threadRaw.isEmpty ? '' : ' • thread=$threadRaw'}';
            final siteDetails = partnerLaneDetailsBySite.putIfAbsent(
              scopeKey,
              () => <String>[],
            );
            if (!siteDetails.contains(detailLine)) {
              siteDetails.add(detailLine);
            }
          }
          final detailLine =
              '$label • chat=${chatId.isEmpty ? 'pending' : chatId}'
              '${threadRaw.isEmpty ? '' : ' • thread=$threadRaw'}';
          final clientDetails = partnerLaneDetailsByClient.putIfAbsent(
            clientId,
            () => <String>[],
          );
          if (!clientDetails.contains(detailLine)) {
            clientDetails.add(detailLine);
          }
        } else {
          telegramCounts.update(
            clientId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }

        final chatcheckStatus = _chatcheckStatusFromEndpointRow(row);
        if (chatcheckStatus.isNotEmpty) {
          if (isPartner) {
            final currentClientStatus =
                partnerChatcheckByClient[clientId] ?? '';
            partnerChatcheckByClient[clientId] = _preferredChatcheckStatus(
              currentClientStatus,
              chatcheckStatus,
            );
          } else {
            final currentClientStatus = chatcheckByClient[clientId] ?? '';
            chatcheckByClient[clientId] = _preferredChatcheckStatus(
              currentClientStatus,
              chatcheckStatus,
            );
          }
          final siteId = (row['site_id'] ?? '').toString().trim();
          if (siteId.isNotEmpty) {
            final scopeKey = _siteScopeKey(clientId, siteId);
            if (isPartner) {
              final currentSiteStatus = partnerChatcheckBySite[scopeKey] ?? '';
              partnerChatcheckBySite[scopeKey] = _preferredChatcheckStatus(
                currentSiteStatus,
                chatcheckStatus,
              );
            } else {
              final currentSiteStatus = chatcheckBySite[scopeKey] ?? '';
              chatcheckBySite[scopeKey] = _preferredChatcheckStatus(
                currentSiteStatus,
                chatcheckStatus,
              );
            }
          }
        }
      }

      if (label.isNotEmpty) {
        final preview =
            (isPartner ? partnerLanePreviewByClient : lanePreviewByClient)
                .putIfAbsent(clientId, () => <String>[]);
        if (!preview.contains(label) && preview.length < 2) {
          preview.add(label);
        }
      }
    }

    final contactCounts = <String, int>{};
    for (final row in contactRows) {
      if (row['is_active'] == false) continue;
      final clientId = (row['client_id'] ?? '').toString().trim();
      if (clientId.isEmpty) continue;
      contactCounts.update(clientId, (value) => value + 1, ifAbsent: () => 1);
    }

    final primarySiteByEmployeeId = <String, String>{};
    for (final assignment in assignmentsRows) {
      final employeeId = (assignment['employee_id'] ?? '').toString().trim();
      final siteId = (assignment['site_id'] ?? '').toString().trim();
      if (employeeId.isEmpty || siteId.isEmpty) continue;
      final isPrimary = assignment['is_primary'] == true;
      if (isPrimary || !primarySiteByEmployeeId.containsKey(employeeId)) {
        primarySiteByEmployeeId[employeeId] = siteId;
      }
    }

    final clients = clientsRows
        .map(_mapClientRow(siteCounts))
        .toList(growable: false);
    final sites = sitesRows.map(_mapSiteRow).toList(growable: false);
    final guards = employeesRows
        .map(_mapEmployeeRow(primarySiteByEmployeeId))
        .toList(growable: false);

    return AdminDirectorySnapshot(
      clients: List<AdminDirectoryClientRow>.unmodifiable(clients),
      sites: List<AdminDirectorySiteRow>.unmodifiable(sites),
      guards: List<AdminDirectoryGuardRow>.unmodifiable(guards),
      clientMessagingEndpointCounts: Map<String, int>.unmodifiable(
        endpointCounts,
      ),
      clientTelegramEndpointCounts: Map<String, int>.unmodifiable(
        telegramCounts,
      ),
      clientMessagingContactCounts: Map<String, int>.unmodifiable(
        contactCounts,
      ),
      clientPartnerEndpointCounts: Map<String, int>.unmodifiable(
        partnerEndpointCounts,
      ),
      clientMessagingLanePreview: Map<String, String>.unmodifiable({
        for (final entry in lanePreviewByClient.entries)
          entry.key: entry.value.join(' • '),
      }),
      clientTelegramChatcheckStatus: Map<String, String>.unmodifiable(
        chatcheckByClient,
      ),
      siteTelegramChatcheckStatus: Map<String, String>.unmodifiable(
        chatcheckBySite,
      ),
      clientPartnerLanePreview: Map<String, String>.unmodifiable({
        for (final entry in partnerLanePreviewByClient.entries)
          entry.key: entry.value.join(' • '),
      }),
      clientPartnerChatcheckStatus: Map<String, String>.unmodifiable(
        partnerChatcheckByClient,
      ),
      clientPartnerLaneDetails: _freezeStringListMap(
        partnerLaneDetailsByClient,
      ),
      sitePartnerEndpointCounts: Map<String, int>.unmodifiable(
        partnerEndpointCountsBySite,
      ),
      sitePartnerChatcheckStatus: Map<String, String>.unmodifiable(
        partnerChatcheckBySite,
      ),
      sitePartnerLaneDetails: _freezeStringListMap(partnerLaneDetailsBySite),
    );
  }

  Future<List<Map<String, dynamic>>> _loadOptionalRows(
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  AdminDirectoryClientRow Function(Map<String, dynamic>) _mapClientRow(
    Map<String, int> siteCounts,
  ) {
    return (Map<String, dynamic> row) {
      final metadata =
          (row['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final id = (row['client_id'] ?? '').toString();
      return AdminDirectoryClientRow(
        id: id,
        name: (row['display_name'] ?? row['legal_name'] ?? id).toString(),
        code: (metadata['code'] ?? id).toString(),
        contactPerson: (row['contact_name'] ?? row['sovereign_contact'] ?? '-')
            .toString(),
        contactEmail: (row['contact_email'] ?? '-').toString(),
        contactPhone: (row['contact_phone'] ?? '-').toString(),
        slaTier: (metadata['sla_tier'] ?? 'standard').toString(),
        contractStart: _dateFromDynamic(row['contract_start']),
        contractEnd: (metadata['contract_end'] ?? '-').toString(),
        sites: siteCounts[id] ?? 0,
        status: (row['is_active'] == false)
            ? AdminDirectoryStatus.inactive
            : AdminDirectoryStatus.active,
      );
    };
  }

  AdminDirectorySiteRow _mapSiteRow(Map<String, dynamic> row) {
    final metadata =
        (row['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final cameraControl =
        (metadata['camera_control_auth'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final hardwareIds =
        (row['hardware_ids'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final firstFsk = hardwareIds.cast<String?>().firstWhere(
      (entry) => (entry ?? '').toUpperCase().contains('FSK'),
      orElse: () => null,
    );
    return AdminDirectorySiteRow(
      id: (row['site_id'] ?? '').toString(),
      name: (row['site_name'] ?? '-').toString(),
      code: (row['site_code'] ?? row['site_id'] ?? '-').toString(),
      clientId: (row['client_id'] ?? '').toString(),
      address:
          (row['physical_address'] ??
                  row['address_line_1'] ??
                  row['address'] ??
                  '-')
              .toString(),
      lat: _doubleFromDynamic(row['latitude']),
      lng: _doubleFromDynamic(row['longitude']),
      contactPerson: '-',
      contactPhone: '-',
      fskNumber: firstFsk,
      geofenceRadiusMeters: _intFromDynamic(row['geofence_radius_meters']),
      cameraAuthMode: (cameraControl['auth_mode'] ?? 'none').toString().trim(),
      cameraUsername: (cameraControl['username'] ?? '').toString().trim(),
      cameraPassword: (cameraControl['password'] ?? '').toString(),
      cameraBearerToken: (cameraControl['bearer_token'] ?? '')
          .toString()
          .trim(),
      status: (row['is_active'] == false)
          ? AdminDirectoryStatus.inactive
          : AdminDirectoryStatus.active,
    );
  }

  AdminDirectoryGuardRow Function(Map<String, dynamic>) _mapEmployeeRow(
    Map<String, String> primarySiteByEmployeeId,
  ) {
    return (Map<String, dynamic> row) {
      final metadata =
          (row['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final employeeUuid = (row['id'] ?? '').toString();
      final fullName = (row['full_name'] ?? '').toString();
      final surname = (row['surname'] ?? '').toString();
      final displayName = '$fullName $surname'.trim();
      final employment = (row['employment_status'] ?? 'active').toString();
      return AdminDirectoryGuardRow(
        id: (row['employee_code'] ?? '').toString(),
        name: displayName.isEmpty
            ? (row['employee_code'] ?? '-').toString()
            : displayName,
        role: (row['primary_role'] ?? 'guard').toString(),
        employeeId: (row['employee_code'] ?? '-').toString(),
        phone: (row['contact_phone'] ?? '-').toString(),
        email: (row['contact_email'] ?? '-').toString(),
        psiraNumber: (row['psira_number'] ?? '').toString(),
        psiraExpiry: _dateFromDynamic(row['psira_expiry']),
        certifications: _employeeCertifications(row),
        assignedSite: primarySiteByEmployeeId[employeeUuid] ?? '',
        shiftPattern: (metadata['shift_pattern'] ?? 'Unassigned').toString(),
        emergencyContact: (metadata['emergency_contact_phone'] ?? '-')
            .toString(),
        status: switch (employment) {
          'suspended' => AdminDirectoryStatus.suspended,
          'terminated' => AdminDirectoryStatus.inactive,
          _ => AdminDirectoryStatus.active,
        },
      );
    };
  }

  Map<String, List<String>> _freezeStringListMap(
    Map<String, List<String>> input,
  ) {
    return Map<String, List<String>>.unmodifiable({
      for (final entry in input.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  String _siteScopeKey(String clientId, String siteId) {
    return '${clientId.trim()}::${siteId.trim()}';
  }

  int _chatcheckSeverity(String status) {
    final uppercase = status.trim().toUpperCase();
    if (uppercase.startsWith('FAIL')) return 3;
    if (uppercase.startsWith('SKIP')) return 2;
    if (uppercase.startsWith('PASS')) return 1;
    return 0;
  }

  String _preferredChatcheckStatus(String current, String candidate) {
    final currentNormalized = current.trim();
    final candidateNormalized = candidate.trim();
    if (candidateNormalized.isEmpty) return currentNormalized;
    if (currentNormalized.isEmpty) return candidateNormalized;
    final currentRank = _chatcheckSeverity(currentNormalized);
    final candidateRank = _chatcheckSeverity(candidateNormalized);
    if (candidateRank > currentRank) {
      return candidateNormalized;
    }
    return currentNormalized;
  }

  String _chatcheckStatusFromEndpointRow(Map<String, dynamic> row) {
    final status = (row['last_delivery_status'] ?? '').toString().trim();
    if (status.isEmpty) return '';
    final normalized = status.toLowerCase();
    final error = (row['last_error'] ?? '').toString().trim();
    final detailSuffix = error.isEmpty ? '' : ' • $error';
    return switch (normalized) {
      'chatcheck_pass' => 'PASS (linked + delivered)',
      'chatcheck_blocked' => 'FAIL (delivery blocked$detailSuffix)',
      'chatcheck_fail' => 'FAIL (delivery error$detailSuffix)',
      'chatcheck_unlinked' => 'FAIL (endpoint not linked in scope)',
      'chatcheck_skip' => 'SKIP${error.isEmpty ? '' : ' ($error)'}',
      _ => '',
    };
  }

  bool _isPartnerEndpointLabel(String label, String prefix) {
    return label.trim().toUpperCase().startsWith(prefix.trim().toUpperCase());
  }

  String _dateFromDynamic(Object? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '-';
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  double _doubleFromDynamic(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _intFromDynamic(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<String> _employeeCertifications(Map<String, dynamic> row) {
    final certs = <String>[];
    final psiraGrade = (row['psira_grade'] ?? '').toString();
    if (psiraGrade.isNotEmpty) {
      certs.add('PSIRA $psiraGrade');
    }
    if (row['has_driver_license'] == true) {
      final code = (row['driver_license_code'] ?? '').toString();
      certs.add(code.isEmpty ? 'Driver License' : 'Driver License $code');
    }
    if (row['has_pdp'] == true) {
      certs.add('PDP');
    }
    final competency =
        (row['firearm_competency'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    for (final entry in competency.entries) {
      if (entry.value == true) {
        certs.add('Firearm ${entry.key}');
      }
    }
    if (certs.isEmpty) {
      certs.add('General');
    }
    return List<String>.unmodifiable(certs);
  }
}
