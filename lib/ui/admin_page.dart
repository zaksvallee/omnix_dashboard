import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/ops_integration_profile.dart';
import '../domain/events/dispatch_event.dart';
import 'onyx_surface.dart';

enum _AdminTab { guards, sites, clients, system }

enum _AdminStatus { active, inactive, suspended }

class _GuardAdminRow {
  final String id;
  final String name;
  final String employeeId;
  final String phone;
  final String email;
  final String psiraNumber;
  final List<String> certifications;
  final String assignedSite;
  final String shiftPattern;
  final String emergencyContact;
  final _AdminStatus status;

  const _GuardAdminRow({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.phone,
    required this.email,
    required this.psiraNumber,
    required this.certifications,
    required this.assignedSite,
    required this.shiftPattern,
    required this.emergencyContact,
    required this.status,
  });
}

class _SiteAdminRow {
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
  final _AdminStatus status;

  const _SiteAdminRow({
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
    required this.status,
  });
}

class _ClientAdminRow {
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
  final _AdminStatus status;

  const _ClientAdminRow({
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

class AdministrationPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final String initialRadioIntentPhrasesJson;
  final Future<void> Function(String rawJson)? onSaveRadioIntentPhrasesJson;
  final Future<void> Function()? onResetRadioIntentPhrasesJson;
  final Future<void> Function()? onRetryRadioQueue;
  final Future<void> Function()? onRunOpsIntegrationPoll;
  final Future<void> Function()? onRunRadioPoll;
  final Future<void> Function()? onRunCctvPoll;
  final Future<void> Function()? onRunWearablePoll;
  final Future<void> Function()? onRunNewsPoll;
  final Future<void> Function()? onClearRadioQueue;
  final Future<void> Function()? onClearRadioQueueFailureSnapshot;
  final bool radioQueueHasPending;
  final String? radioOpsPollHealth;
  final String? radioOpsQueueHealth;
  final String? radioOpsQueueIntentMix;
  final String? radioOpsAckRecentSummary;
  final String? radioOpsQueueStateDetail;
  final String? radioOpsFailureDetail;
  final String? radioOpsFailureAuditDetail;
  final String? radioOpsManualActionDetail;
  final String? cctvOpsPollHealth;
  final String? cctvCapabilitySummary;
  final String? cctvRecentSignalSummary;
  final String? wearableOpsPollHealth;
  final String? newsOpsPollHealth;

  const AdministrationPage({
    super.key,
    required this.events,
    this.initialRadioIntentPhrasesJson = '',
    this.onSaveRadioIntentPhrasesJson,
    this.onResetRadioIntentPhrasesJson,
    this.onRetryRadioQueue,
    this.onRunOpsIntegrationPoll,
    this.onRunRadioPoll,
    this.onRunCctvPoll,
    this.onRunWearablePoll,
    this.onRunNewsPoll,
    this.onClearRadioQueue,
    this.onClearRadioQueueFailureSnapshot,
    this.radioQueueHasPending = false,
    this.radioOpsPollHealth,
    this.radioOpsQueueHealth,
    this.radioOpsQueueIntentMix,
    this.radioOpsAckRecentSummary,
    this.radioOpsQueueStateDetail,
    this.radioOpsFailureDetail,
    this.radioOpsFailureAuditDetail,
    this.radioOpsManualActionDetail,
    this.cctvOpsPollHealth,
    this.cctvCapabilitySummary,
    this.cctvRecentSignalSummary,
    this.wearableOpsPollHealth,
    this.newsOpsPollHealth,
  });

  @override
  State<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends State<AdministrationPage> {
  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _radioIntentPhrasesController =
      TextEditingController(text: _resolvedInitialRadioIntentPhrasesJson());

  _AdminTab _activeTab = _AdminTab.guards;
  String _query = '';
  bool _radioIntentPhrasesSaving = false;
  String? _radioIntentPhraseValidation;
  bool _radioIntentPhraseValidationError = false;

  List<_GuardAdminRow> _guards = const [
    _GuardAdminRow(
      id: 'GRD-001',
      name: 'Thabo Mokoena',
      employeeId: 'EMP-441',
      phone: '+27 82 555 0441',
      email: 'thabo.m@onyx-security.co.za',
      psiraNumber: 'PSI-441-2024',
      certifications: ['PSIRA', 'Armed Response', 'First Aid'],
      assignedSite: 'WTF-MAIN',
      shiftPattern: 'Night (18:00-06:00)',
      emergencyContact: '+27 82 555 0442',
      status: _AdminStatus.active,
    ),
    _GuardAdminRow(
      id: 'GRD-002',
      name: 'Sipho Ndlovu',
      employeeId: 'EMP-442',
      phone: '+27 83 444 0442',
      email: 'sipho.n@onyx-security.co.za',
      psiraNumber: 'PSI-442-2024',
      certifications: ['PSIRA', 'Armed Response', 'Fire Safety'],
      assignedSite: 'BLR-MAIN',
      shiftPattern: 'Night (18:00-06:00)',
      emergencyContact: '+27 83 444 0443',
      status: _AdminStatus.active,
    ),
    _GuardAdminRow(
      id: 'GRD-003',
      name: 'Nomsa Khumalo',
      employeeId: 'EMP-443',
      phone: '+27 84 333 0443',
      email: 'nomsa.k@onyx-security.co.za',
      psiraNumber: 'PSI-443-2024',
      certifications: ['PSIRA', 'First Aid', 'CPR'],
      assignedSite: 'SDN-NORTH',
      shiftPattern: 'Day (06:00-18:00)',
      emergencyContact: '+27 84 333 0444',
      status: _AdminStatus.active,
    ),
  ];

  List<_SiteAdminRow> _sites = const [
    _SiteAdminRow(
      id: 'WTF-MAIN',
      name: 'Waterfall Estate Main',
      code: 'WTF-MAIN',
      clientId: 'CLT-001',
      address: '123 Waterfall Drive, Midrand, 1686',
      lat: -26.0285,
      lng: 28.1122,
      contactPerson: 'John Smith',
      contactPhone: '+27 11 555 0001',
      fskNumber: 'FSK-WTF-001',
      geofenceRadiusMeters: 500,
      status: _AdminStatus.active,
    ),
    _SiteAdminRow(
      id: 'BLR-MAIN',
      name: 'Blue Ridge Security',
      code: 'BLR-MAIN',
      clientId: 'CLT-002',
      address: '45 Ridge Road, Johannesburg, 2001',
      lat: -26.1234,
      lng: 28.0567,
      contactPerson: 'Sarah Johnson',
      contactPhone: '+27 11 555 0002',
      fskNumber: 'FSK-BLR-001',
      geofenceRadiusMeters: 300,
      status: _AdminStatus.active,
    ),
    _SiteAdminRow(
      id: 'SDN-NORTH',
      name: 'Sandton Estate North',
      code: 'SDN-NORTH',
      clientId: 'CLT-001',
      address: '78 North Avenue, Sandton, 2196',
      lat: -26.0789,
      lng: 28.0456,
      contactPerson: 'Michael Brown',
      contactPhone: '+27 11 555 0003',
      fskNumber: 'FSK-SDN-001',
      geofenceRadiusMeters: 400,
      status: _AdminStatus.active,
    ),
  ];

  List<_ClientAdminRow> _clients = const [
    _ClientAdminRow(
      id: 'CLT-001',
      name: 'Waterfall Estates Group',
      code: 'WTF-GRP',
      contactPerson: 'David Wilson',
      contactEmail: 'david.wilson@waterfall.co.za',
      contactPhone: '+27 11 888 0001',
      slaTier: 'platinum',
      contractStart: '2024-01-01',
      contractEnd: '2026-12-31',
      sites: 2,
      status: _AdminStatus.active,
    ),
    _ClientAdminRow(
      id: 'CLT-002',
      name: 'Blue Ridge Properties',
      code: 'BLR-PROP',
      contactPerson: 'Lisa Anderson',
      contactEmail: 'lisa.a@blueridge.co.za',
      contactPhone: '+27 11 888 0002',
      slaTier: 'gold',
      contractStart: '2024-03-01',
      contractEnd: '2025-02-28',
      sites: 1,
      status: _AdminStatus.active,
    ),
    _ClientAdminRow(
      id: 'CLT-003',
      name: 'Centurion Business Park',
      code: 'CNT-BIZ',
      contactPerson: 'Robert Taylor',
      contactEmail: 'robert.t@centurion.co.za',
      contactPhone: '+27 11 888 0003',
      slaTier: 'silver',
      contractStart: '2024-06-01',
      contractEnd: '2025-05-31',
      sites: 1,
      status: _AdminStatus.active,
    ),
  ];

  @override
  void didUpdateWidget(covariant AdministrationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRadioIntentPhrasesJson !=
        widget.initialRadioIntentPhrasesJson) {
      _radioIntentPhrasesController.text =
          _resolvedInitialRadioIntentPhrasesJson();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _radioIntentPhrasesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnyxPageHeader(
                  title: 'System Administration',
                  subtitle:
                      'Manage guards, sites, clients, and system configuration',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () => _snack('Export started'),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8FD1FF),
                        side: const BorderSide(color: Color(0xFF35506F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Export Data',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _snack('CSV import staged'),
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: const Color(0xFFEAF4FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Import CSV',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tabBar(),
                const SizedBox(height: 12),
                OnyxSectionCard(
                  title: 'Administration Console',
                  subtitle:
                      'Search, inspect, and maintain operational configuration records.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _toolbar(),
                      const SizedBox(height: 12),
                      _activeTabBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = [
      (_AdminTab.guards, 'Guards', Icons.shield_rounded, _guards.length),
      (_AdminTab.sites, 'Sites', Icons.apartment_rounded, _sites.length),
      (
        _AdminTab.clients,
        'Clients',
        Icons.business_center_rounded,
        _clients.length,
      ),
      (_AdminTab.system, 'System', Icons.settings_rounded, null),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33223344))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs
            .map((tab) {
              final active = _activeTab == tab.$1;
              return InkWell(
                onTap: () => setState(() => _activeTab = tab.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0x1A22D3EE)
                        : const Color(0xFF0E1A2B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? const Color(0x6622D3EE)
                          : const Color(0x332B425F),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.$3,
                        size: 16,
                        color: active
                            ? const Color(0xFF22D3EE)
                            : const Color(0xFF9AB1CF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.$2,
                        style: GoogleFonts.inter(
                          color: active
                              ? const Color(0xFFEAF4FF)
                              : const Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tab.$4 != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x22000000),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0x332B425F)),
                          ),
                          child: Text(
                            '${tab.$4}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8EA4C2),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _toolbar() {
    final label = switch (_activeTab) {
      _AdminTab.guards => 'Guard',
      _AdminTab.sites => 'Site',
      _AdminTab.clients => 'Client',
      _AdminTab.system => 'Item',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final search = TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim()),
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: Color(0xFF8EA4C2),
            ),
            hintText: 'Search ${_activeTab.name}...',
            hintStyle: GoogleFonts.inter(
              color: const Color(0x668EA4C2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFF0C1117),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x332B425F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x332B425F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x8022D3EE)),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: () => _showEditStub(label),
          icon: const Icon(Icons.add_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2B5E93),
            foregroundColor: const Color(0xFFEAF4FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            'Add $label',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 8), addButton],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            addButton,
          ],
        );
      },
    );
  }

  Widget _activeTabBody() {
    return switch (_activeTab) {
      _AdminTab.guards => _guardsTable(),
      _AdminTab.sites => _sitesTable(),
      _AdminTab.clients => _clientsTable(),
      _AdminTab.system => _systemTab(),
    };
  }

  Widget _guardsTable() {
    final filtered = _guards
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.employeeId.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.id})',
                lines: [
                  'Employee: ${row.employeeId} • ${row.psiraNumber}',
                  'Contact: ${row.phone} • ${row.email}',
                  'Assigned Site: ${_siteName(row.assignedSite)} • ${row.shiftPattern}',
                  'Emergency: ${row.emergencyContact}',
                  'Certifications: ${row.certifications.join(', ')}',
                ],
                status: row.status,
                onEdit: () => _showEditStub('Guard'),
                onDelete: () => _deleteGuard(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _sitesTable() {
    final filtered = _sites
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.code.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.code})',
                lines: [
                  'Client: ${_clientName(row.clientId)}',
                  'Address: ${row.address}',
                  'Coordinates: ${row.lat.toStringAsFixed(4)}, ${row.lng.toStringAsFixed(4)}',
                  'Contact: ${row.contactPerson} • ${row.contactPhone}',
                  'FSK: ${row.fskNumber ?? '-'} • Geofence: ${row.geofenceRadiusMeters}m',
                ],
                status: row.status,
                onEdit: () => _showEditStub('Site'),
                onDelete: () => _deleteSite(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _clientsTable() {
    final filtered = _clients
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.code.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.code})',
                lines: [
                  'Contact: ${row.contactPerson} • ${row.contactPhone}',
                  'Email: ${row.contactEmail}',
                  'SLA Tier: ${row.slaTier.toUpperCase()} • Sites: ${row.sites}',
                  'Contract: ${row.contractStart} to ${row.contractEnd}',
                ],
                status: row.status,
                onEdit: () => _showEditStub('Client'),
                onDelete: () => _deleteClient(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _systemTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final children = [
              Expanded(child: _slaCard()),
              const SizedBox(width: 10, height: 10),
              Expanded(child: _policyCard()),
            ];
            if (compact) {
              return Column(
                children: [
                  _slaCard(),
                  const SizedBox(height: 10),
                  _policyCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          },
        ),
        const SizedBox(height: 10),
        _radioIntentPhraseCard(),
        const SizedBox(height: 10),
        _systemInfoCard(),
      ],
    );
  }

  Widget _radioIntentPhraseCard() {
    final hasOverride = widget.initialRadioIntentPhrasesJson.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Radio Intent Dictionary'),
          const SizedBox(height: 8),
          Text(
            'Tune panic/duress/all-clear/status phrase detection at runtime.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _radioIntentPhrasesController,
            maxLines: 10,
            minLines: 8,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText:
                  '{\n  "all_clear": ["all clear"],\n  "panic": ["panic button"],\n  "duress": ["silent duress"],\n  "status": ["status update"]\n}',
              hintStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF6A829F),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFF0C1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x6655A4FF)),
              ),
            ),
          ),
          if (_radioIntentPhraseValidation != null) ...[
            const SizedBox(height: 8),
            Text(
              _radioIntentPhraseValidation!,
              style: GoogleFonts.inter(
                color: _radioIntentPhraseValidationError
                    ? const Color(0xFFF87171)
                    : const Color(0xFF67E8F9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _validateRadioIntentJson,
                icon: const Icon(Icons.rule_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5E93),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Validate',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _saveRadioIntentJson,
                icon: const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Save Runtime',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _resetRadioIntentJson,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9AB1CF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                ),
                label: Text(
                  hasOverride ? 'Reset To Defaults' : 'Defaults Active',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slaCard() {
    final tiers = [
      ('Platinum', '< 5 min', const Color(0xFF22D3EE)),
      ('Gold', '< 10 min', const Color(0xFFF59E0B)),
      ('Silver', '< 15 min', const Color(0xFF94A3B8)),
      ('Bronze', '< 20 min', const Color(0xFFFB923C)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('SLA Tiers'),
          const SizedBox(height: 8),
          ...tiers.map((tier) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tier.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tier.$1,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    tier.$2,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 12,
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

  Widget _policyCard() {
    final policies = [
      ('Auto-escalate after', '30 seconds'),
      ('Critical incident timeout', '5 minutes'),
      ('Guard heartbeat interval', '60 seconds'),
      ('Geofence breach alert', 'Enabled'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Risk Policies'),
          const SizedBox(height: 8),
          ...policies.map((policy) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      policy.$1,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB1CF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    policy.$2,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _systemInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('System Information'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sysInfoMini('Total Guards', _guards.length.toString()),
              _sysInfoMini('Total Sites', _sites.length.toString()),
              _sysInfoMini('Total Clients', _clients.length.toString()),
            ],
          ),
          if (_opsPollHealthRows().isNotEmpty) ...[
            const SizedBox(height: 12),
            _subTitle('Ops Integration Poll Health'),
            const SizedBox(height: 8),
            ..._opsPollHealthRows(),
            const SizedBox(height: 8),
            _opsQueueActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _opsQueueActionButtons() {
    final hasPending = widget.radioQueueHasPending;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onRunOpsIntegrationPoll != null
              ? () async {
                  await widget.onRunOpsIntegrationPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7DD3FC),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.sync_rounded, size: 16),
          label: Text(
            'Run Ops Poll Now',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunRadioPoll != null
              ? () async {
                  await widget.onRunRadioPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.sensors_rounded, size: 16),
          label: Text(
            'Poll Radio',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunCctvPoll != null
              ? () async {
                  await widget.onRunCctvPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF93C5FD),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.videocam_rounded, size: 16),
          label: Text(
            'Poll CCTV',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunWearablePoll != null
              ? () async {
                  await widget.onRunWearablePoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF34D399),
            side: const BorderSide(color: Color(0xFF2F5949)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.watch_rounded, size: 16),
          label: Text(
            'Poll Wearable',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunNewsPoll != null
              ? () async {
                  await widget.onRunNewsPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFF5B3A16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.newspaper_rounded, size: 16),
          label: Text(
            'Poll News',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: hasPending && widget.onRetryRadioQueue != null
              ? () async {
                  await widget.onRetryRadioQueue!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            'Retry Radio Queue',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: hasPending && widget.onClearRadioQueue != null
              ? () async {
                  await _confirmClearRadioQueue();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF87171),
            side: const BorderSide(color: Color(0xFF5B242C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.clear_all_rounded, size: 16),
          label: Text(
            'Clear Radio Queue',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onClearRadioQueueFailureSnapshot != null
              ? () async {
                  await _confirmClearRadioFailureSnapshot();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFF5B3A16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.history_toggle_off_rounded, size: 16),
          label: Text(
            'Clear Last Failure',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearRadioQueue() async {
    if (!widget.radioQueueHasPending || widget.onClearRadioQueue == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Clear Radio Queue?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This removes all pending automated radio responses from the queue.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Confirm Clear',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onClearRadioQueue!.call();
    }
  }

  Future<void> _confirmClearRadioFailureSnapshot() async {
    if (widget.onClearRadioQueueFailureSnapshot == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Clear Last Failure Snapshot?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This clears the persisted last radio failure snapshot from system diagnostics.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Confirm Clear',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onClearRadioQueueFailureSnapshot!.call();
    }
  }

  List<Widget> _opsPollHealthRows() {
    final rows = <(String, String)>[];
    if ((widget.radioOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('Radio', widget.radioOpsPollHealth!.trim()));
    }
    if ((widget.radioOpsQueueHealth ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue', widget.radioOpsQueueHealth!.trim()));
    }
    if ((widget.radioOpsQueueIntentMix ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue Mix', widget.radioOpsQueueIntentMix!.trim()));
    }
    if ((widget.radioOpsAckRecentSummary ?? '').trim().isNotEmpty) {
      rows.add(('Radio ACK Recent', widget.radioOpsAckRecentSummary!.trim()));
    }
    if ((widget.radioOpsQueueStateDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue State', widget.radioOpsQueueStateDetail!.trim()));
    }
    if ((widget.radioOpsFailureDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Failure', widget.radioOpsFailureDetail!.trim()));
    }
    if ((widget.radioOpsFailureAuditDetail ?? '').trim().isNotEmpty) {
      rows.add((
        'Radio Failure Audit',
        widget.radioOpsFailureAuditDetail!.trim(),
      ));
    }
    if ((widget.radioOpsManualActionDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Action', widget.radioOpsManualActionDetail!.trim()));
    }
    if ((widget.cctvOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('CCTV', widget.cctvOpsPollHealth!.trim()));
    }
    if ((widget.cctvCapabilitySummary ?? '').trim().isNotEmpty) {
      rows.add(('CCTV Caps', widget.cctvCapabilitySummary!.trim()));
    }
    if ((widget.cctvRecentSignalSummary ?? '').trim().isNotEmpty) {
      rows.add(('CCTV Recent', widget.cctvRecentSignalSummary!.trim()));
    }
    if ((widget.wearableOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('Wearable', widget.wearableOpsPollHealth!.trim()));
    }
    if ((widget.newsOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('News', widget.newsOpsPollHealth!.trim()));
    }
    return rows
        .map(
          (row) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1117),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x332B425F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    row.$1.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.$2,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF67E8F9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _sysInfoMini(String label, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCard({
    required String title,
    required List<String> lines,
    required _AdminStatus status,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusChip(status),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit',
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Color(0xFF60A5FA),
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_rounded,
                  size: 16,
                  color: Color(0xFFF87171),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_AdminStatus status) {
    final (label, fg, bg, border) = switch (status) {
      _AdminStatus.active => (
        'ACTIVE',
        const Color(0xFF10B981),
        const Color(0x1A10B981),
        const Color(0x6610B981),
      ),
      _AdminStatus.inactive => (
        'INACTIVE',
        const Color(0xFF94A3B8),
        const Color(0x1A94A3B8),
        const Color(0x6694A3B8),
      ),
      _AdminStatus.suspended => (
        'SUSPENDED',
        const Color(0xFFEF4444),
        const Color(0x1AEF4444),
        const Color(0x66EF4444),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF30363D)),
    );
  }

  Widget _subTitle(String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF3C79BB),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _siteName(String id) {
    for (final site in _sites) {
      if (site.id == id) return site.name;
    }
    return 'Unassigned';
  }

  String _clientName(String id) {
    for (final client in _clients) {
      if (client.id == id) return client.name;
    }
    return 'Unknown Client';
  }

  void _deleteGuard(String id) {
    setState(() {
      _guards = _guards
          .where((guard) => guard.id != id)
          .toList(growable: false);
    });
    _snack('Guard $id deleted');
  }

  void _deleteSite(String id) {
    setState(() {
      _sites = _sites.where((site) => site.id != id).toList(growable: false);
    });
    _snack('Site $id deleted');
  }

  void _deleteClient(String id) {
    setState(() {
      _clients = _clients
          .where((client) => client.id != id)
          .toList(growable: false);
    });
    _snack('Client $id deleted');
  }

  Future<void> _showEditStub(String label) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add $label',
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Form implementation ready for Supabase integration.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9AB1CF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _snack('$label saved');
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: const Color(0xFFEAF4FF),
                      ),
                      label: Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _resolvedInitialRadioIntentPhrasesJson() {
    final raw = widget.initialRadioIntentPhrasesJson.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return '';
  }

  Future<void> _validateRadioIntentJson() async {
    final raw = _radioIntentPhrasesController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _radioIntentPhraseValidation =
            'Valid: empty config uses default phrases.';
        _radioIntentPhraseValidationError = false;
      });
      return;
    }
    final parsed = OnyxRadioIntentPhraseCatalog.tryParseJsonString(raw);
    if (parsed == null) {
      setState(() {
        _radioIntentPhraseValidation =
            'Invalid JSON or missing phrase arrays for all_clear/panic/duress/status.';
        _radioIntentPhraseValidationError = true;
      });
      return;
    }
    setState(() {
      _radioIntentPhraseValidation =
          'Valid: all_clear=${parsed.allClearPhrases.length}, panic=${parsed.panicPhrases.length}, duress=${parsed.duressPhrases.length}, status=${parsed.statusPhrases.length}.';
      _radioIntentPhraseValidationError = false;
    });
  }

  Future<void> _saveRadioIntentJson() async {
    await _validateRadioIntentJson();
    if (_radioIntentPhraseValidationError) {
      return;
    }
    if (widget.onSaveRadioIntentPhrasesJson == null) {
      _snack('Runtime save is not wired.');
      return;
    }
    setState(() {
      _radioIntentPhrasesSaving = true;
    });
    try {
      await widget.onSaveRadioIntentPhrasesJson!(
        _radioIntentPhrasesController.text,
      );
      if (!mounted) return;
      _snack('Radio intent dictionary saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _radioIntentPhraseValidation = error.toString();
        _radioIntentPhraseValidationError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _radioIntentPhrasesSaving = false;
        });
      }
    }
  }

  Future<void> _resetRadioIntentJson() async {
    _radioIntentPhrasesController.clear();
    if (widget.onResetRadioIntentPhrasesJson != null) {
      await widget.onResetRadioIntentPhrasesJson!();
    }
    if (!mounted) return;
    setState(() {
      _radioIntentPhraseValidation = 'Default phrase dictionary restored.';
      _radioIntentPhraseValidationError = false;
    });
    _snack('Radio intent dictionary reset.');
  }
}
