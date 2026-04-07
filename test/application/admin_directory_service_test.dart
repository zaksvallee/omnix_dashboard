import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/admin/admin_directory_service.dart';

class _FakeAdminDirectoryDataSource implements AdminDirectoryDataSource {
  _FakeAdminDirectoryDataSource({
    this.clients = const <Map<String, dynamic>>[],
    this.sites = const <Map<String, dynamic>>[],
    this.employees = const <Map<String, dynamic>>[],
    this.assignments = const <Map<String, dynamic>>[],
    this.endpoints = const <Map<String, dynamic>>[],
    this.contacts = const <Map<String, dynamic>>[],
    this.throwOnEndpoints = false,
    this.throwOnContacts = false,
  });

  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> sites;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> endpoints;
  final List<Map<String, dynamic>> contacts;
  final bool throwOnEndpoints;
  final bool throwOnContacts;

  @override
  Future<List<Map<String, dynamic>>> fetchAssignments() async => assignments;

  @override
  Future<List<Map<String, dynamic>>> fetchClientContacts() async {
    if (throwOnContacts) {
      throw StateError('client_contacts unavailable');
    }
    return contacts;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClients() async => clients;

  @override
  Future<List<Map<String, dynamic>>> fetchEmployees() async => employees;

  @override
  Future<List<Map<String, dynamic>>> fetchMessagingEndpoints() async {
    if (throwOnEndpoints) {
      throw StateError('client_messaging_endpoints unavailable');
    }
    return endpoints;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSites() async => sites;
}

void main() {
  group('AdminDirectoryService', () {
    test(
      'maps directory rows into typed snapshot and lane telemetry',
      () async {
        const service = AdminDirectoryService();

        final snapshot = await service.loadDirectoryFromDataSource(
          dataSource: _FakeAdminDirectoryDataSource(
            clients: <Map<String, dynamic>>[
              <String, dynamic>{
                'client_id': 'CLIENT-1',
                'display_name': 'MS Vallee Residence',
                'contact_name': 'M. Vallee',
                'contact_email': 'ops@vallee.test',
                'contact_phone': '+27110000000',
                'contract_start': '2026-01-02T00:00:00Z',
                'is_active': true,
                'metadata': <String, dynamic>{
                  'code': 'MSV',
                  'sla_tier': 'platinum',
                  'contract_end': '2026-12-31',
                },
              },
            ],
            sites: <Map<String, dynamic>>[
              <String, dynamic>{
                'site_id': 'SITE-1',
                'site_name': 'East Gate',
                'site_code': 'EAST',
                'client_id': 'CLIENT-1',
                'physical_address': '1 Security Road',
                'latitude': '-26.2041',
                'longitude': '28.0473',
                'hardware_ids': <String>['FSK-12345', 'NVR-1'],
                'geofence_radius_meters': '150',
                'is_active': true,
              },
            ],
            employees: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'EMP-UUID-1',
                'employee_code': 'EMP-001',
                'full_name': 'Ava',
                'surname': 'Stone',
                'primary_role': 'supervisor',
                'contact_phone': '+27119990000',
                'contact_email': 'ava@omnix.test',
                'psira_number': 'PSIRA-44',
                'psira_expiry': '2027-02-03T00:00:00Z',
                'psira_grade': 'A',
                'has_driver_license': true,
                'driver_license_code': 'EB',
                'has_pdp': true,
                'firearm_competency': <String, dynamic>{
                  'handgun': true,
                  'rifle': false,
                },
                'employment_status': 'suspended',
                'metadata': <String, dynamic>{
                  'shift_pattern': 'Night Shift',
                  'emergency_contact_phone': '+27118887777',
                },
              },
            ],
            assignments: <Map<String, dynamic>>[
              <String, dynamic>{
                'employee_id': 'EMP-UUID-1',
                'site_id': 'SITE-1',
                'assignment_status': 'active',
                'is_primary': true,
              },
            ],
            endpoints: <Map<String, dynamic>>[
              <String, dynamic>{
                'client_id': 'CLIENT-1',
                'site_id': 'SITE-1',
                'provider': 'telegram',
                'is_active': true,
                'display_label': 'Primary Telegram Bridge',
                'telegram_chat_id': 'chat-1',
                'telegram_thread_id': '101',
                'last_delivery_status': 'chatcheck_pass',
                'last_error': '',
              },
              <String, dynamic>{
                'client_id': 'CLIENT-1',
                'site_id': 'SITE-1',
                'provider': 'telegram',
                'is_active': true,
                'display_label': 'PARTNER Dispatch',
                'telegram_chat_id': 'chat-2',
                'telegram_thread_id': '202',
                'last_delivery_status': 'chatcheck_blocked',
                'last_error': '403 forbidden',
              },
              <String, dynamic>{
                'client_id': 'CLIENT-1',
                'site_id': '',
                'provider': 'sms',
                'is_active': true,
                'display_label': 'SMS Bridge',
                'telegram_chat_id': '',
                'telegram_thread_id': '',
                'last_delivery_status': '',
                'last_error': '',
              },
            ],
            contacts: <Map<String, dynamic>>[
              <String, dynamic>{'client_id': 'CLIENT-1', 'is_active': true},
              <String, dynamic>{'client_id': 'CLIENT-1', 'is_active': false},
            ],
          ),
        );

        expect(snapshot.clients, hasLength(1));
        expect(snapshot.sites, hasLength(1));
        expect(snapshot.guards, hasLength(1));

        final client = snapshot.clients.single;
        expect(client.id, 'CLIENT-1');
        expect(client.name, 'MS Vallee Residence');
        expect(client.code, 'MSV');
        expect(client.contactPerson, 'M. Vallee');
        expect(client.contactEmail, 'ops@vallee.test');
        expect(client.contactPhone, '+27110000000');
        expect(client.slaTier, 'platinum');
        expect(client.contractStart, '2026-01-02');
        expect(client.contractEnd, '2026-12-31');
        expect(client.sites, 1);
        expect(client.status, AdminDirectoryStatus.active);

        final site = snapshot.sites.single;
        expect(site.id, 'SITE-1');
        expect(site.name, 'East Gate');
        expect(site.code, 'EAST');
        expect(site.clientId, 'CLIENT-1');
        expect(site.address, '1 Security Road');
        expect(site.lat, closeTo(-26.2041, 0.0001));
        expect(site.lng, closeTo(28.0473, 0.0001));
        expect(site.fskNumber, 'FSK-12345');
        expect(site.geofenceRadiusMeters, 150);
        expect(site.status, AdminDirectoryStatus.active);

        final guard = snapshot.guards.single;
        expect(guard.id, 'EMP-001');
        expect(guard.name, 'Ava Stone');
        expect(guard.role, 'supervisor');
        expect(guard.employeeId, 'EMP-001');
        expect(guard.phone, '+27119990000');
        expect(guard.email, 'ava@omnix.test');
        expect(guard.psiraNumber, 'PSIRA-44');
        expect(guard.psiraExpiry, '2027-02-03');
        expect(
          guard.certifications,
          containsAll(<String>[
            'PSIRA A',
            'Driver License EB',
            'PDP',
            'Firearm handgun',
          ]),
        );
        expect(guard.assignedSite, 'SITE-1');
        expect(guard.shiftPattern, 'Night Shift');
        expect(guard.emergencyContact, '+27118887777');
        expect(guard.status, AdminDirectoryStatus.suspended);

        expect(snapshot.clientMessagingEndpointCounts['CLIENT-1'], 3);
        expect(snapshot.clientTelegramEndpointCounts['CLIENT-1'], 1);
        expect(snapshot.clientMessagingContactCounts['CLIENT-1'], 1);
        expect(snapshot.clientPartnerEndpointCounts['CLIENT-1'], 1);
        expect(
          snapshot.clientMessagingLanePreview['CLIENT-1'],
          'Primary Telegram Bridge • SMS Bridge',
        );
        expect(
          snapshot.clientPartnerLanePreview['CLIENT-1'],
          'PARTNER Dispatch',
        );
        expect(
          snapshot.clientTelegramChatcheckStatus['CLIENT-1'],
          'PASS (linked + delivered)',
        );
        expect(
          snapshot.siteTelegramChatcheckStatus['CLIENT-1::SITE-1'],
          'PASS (linked + delivered)',
        );
        expect(
          snapshot.clientPartnerChatcheckStatus['CLIENT-1'],
          'FAIL (delivery blocked • 403 forbidden)',
        );
        expect(snapshot.sitePartnerEndpointCounts['CLIENT-1::SITE-1'], 1);
        expect(
          snapshot.sitePartnerChatcheckStatus['CLIENT-1::SITE-1'],
          'FAIL (delivery blocked • 403 forbidden)',
        );
        expect(
          snapshot.clientPartnerLaneDetails['CLIENT-1'],
          contains('PARTNER Dispatch • chat=chat-2 • thread=202'),
        );
        expect(
          snapshot.sitePartnerLaneDetails['CLIENT-1::SITE-1'],
          contains('PARTNER Dispatch • chat=chat-2 • thread=202'),
        );
      },
    );

    test(
      'preserves core directory snapshot when optional endpoint reads fail',
      () async {
        const service = AdminDirectoryService();

        final snapshot = await service.loadDirectoryFromDataSource(
          dataSource: _FakeAdminDirectoryDataSource(
            clients: <Map<String, dynamic>>[
              <String, dynamic>{
                'client_id': 'CLIENT-1',
                'display_name': 'MS Vallee Residence',
                'is_active': true,
                'metadata': <String, dynamic>{},
              },
            ],
            sites: <Map<String, dynamic>>[
              <String, dynamic>{
                'site_id': 'SITE-1',
                'site_name': 'East Gate',
                'client_id': 'CLIENT-1',
                'is_active': true,
              },
            ],
            employees: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'EMP-UUID-1',
                'employee_code': 'EMP-001',
                'full_name': 'Ava',
                'surname': 'Stone',
                'employment_status': 'active',
              },
            ],
            assignments: <Map<String, dynamic>>[
              <String, dynamic>{
                'employee_id': 'EMP-UUID-1',
                'site_id': 'SITE-1',
                'assignment_status': 'active',
                'is_primary': true,
              },
            ],
            throwOnEndpoints: true,
            throwOnContacts: true,
          ),
        );

        expect(snapshot.clients, hasLength(1));
        expect(snapshot.sites, hasLength(1));
        expect(snapshot.guards, hasLength(1));
        expect(snapshot.clientMessagingEndpointCounts, isEmpty);
        expect(snapshot.clientTelegramEndpointCounts, isEmpty);
        expect(snapshot.clientMessagingContactCounts, isEmpty);
        expect(snapshot.clientPartnerEndpointCounts, isEmpty);
        expect(snapshot.clientMessagingLanePreview, isEmpty);
        expect(snapshot.clientTelegramChatcheckStatus, isEmpty);
        expect(snapshot.siteTelegramChatcheckStatus, isEmpty);
        expect(snapshot.clientPartnerLanePreview, isEmpty);
        expect(snapshot.clientPartnerChatcheckStatus, isEmpty);
        expect(snapshot.clientPartnerLaneDetails, isEmpty);
        expect(snapshot.sitePartnerEndpointCounts, isEmpty);
        expect(snapshot.sitePartnerChatcheckStatus, isEmpty);
        expect(snapshot.sitePartnerLaneDetails, isEmpty);
      },
    );
  });
}
