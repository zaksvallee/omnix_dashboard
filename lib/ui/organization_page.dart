import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

class OrgPerson {
  final String name;
  final String role;
  final String division;
  final Color divisionColor;
  final String email;
  final String phone;
  final List<OrgPerson> reports;
  bool expanded;

  OrgPerson({
    required this.name,
    required this.role,
    required this.division,
    required this.divisionColor,
    required this.email,
    required this.phone,
    this.reports = const <OrgPerson>[],
    this.expanded = true,
  });
}

Future<void> openOrganizationPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const OrganizationPage(),
    ),
  );
}

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({super.key});

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  int _tab = 0;
  late OrgPerson _root;

  @override
  void initState() {
    super.initState();
    _root = _seedOrgTree();
  }

  int get _totalPeople => _countPeople(_root);

  int _countPeople(OrgPerson person) {
    var total = 1;
    for (final report in person.reports) {
      total += _countPeople(report);
    }
    return total;
  }

  OrgPerson get _opsManager =>
      _root.reports.isNotEmpty ? _root.reports.first : _root;

  int get _divisionCount {
    final divisions = <String>{};
    void visit(OrgPerson person) {
      if (person != _root && person != _opsManager) {
        divisions.add(person.division);
      }
      for (final report in person.reports) {
        visit(report);
      }
    }

    visit(_root);
    return divisions.length;
  }

  int get _teamCount => (_totalPeople - 1).clamp(0, 999);

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(context),
                const SizedBox(height: 20),
                _tabBar(),
                const SizedBox(height: 16),
                _summaryStatsRow(),
                const SizedBox(height: 20),
                if (_tab == 0) _hierarchyTreeView() else _byDivisionView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _pageHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: OnyxColorTokens.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OnyxColorTokens.borderSubtle),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            color: OnyxColorTokens.brand,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: OnyxColorTokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Command structure and reporting hierarchy',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: OnyxColorTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: OnyxColorTokens.textSecondary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _tabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OnyxColorTokens.divider)),
      ),
      child: Row(
        children: [
          _orgTab('Hierarchy tree', 0),
          _orgTab('By division', 1),
        ],
      ),
    );
  }

  Widget _orgTab(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? OnyxColorTokens.backgroundPrimary : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? OnyxColorTokens.brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? OnyxColorTokens.textPrimary
                : OnyxColorTokens.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Summary stats ─────────────────────────────────────────────────────────

  Widget _summaryStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final cards = <Widget>[
          _orgStatCard(
            Icons.workspace_premium_rounded,
            '1',
            'Owner',
            OnyxColorTokens.accentAmber,
          ),
          _orgStatCard(
            Icons.adjust_rounded,
            '1',
            'Ops Manager',
            OnyxColorTokens.brand,
          ),
          _orgStatCard(
            Icons.people_alt_rounded,
            '$_divisionCount',
            'Divisions',
            OnyxColorTokens.accentCyanTrue,
          ),
          _orgStatCard(
            Icons.shield_rounded,
            '$_teamCount',
            'Teams',
            OnyxColorTokens.accentGreen,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                SizedBox(width: double.infinity, child: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _orgStatCard(
    IconData icon,
    String count,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(color: OnyxColorTokens.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: OnyxColorTokens.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: OnyxColorTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 0 — Hierarchy tree ────────────────────────────────────────────────

  Widget _hierarchyTreeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildTreeNodes(_root, 0),
    );
  }

  List<Widget> _buildTreeNodes(OrgPerson person, int depth) {
    final nodes = <Widget>[_personCard(person, depth)];
    if (person.expanded) {
      for (final report in person.reports) {
        nodes.addAll(_buildTreeNodes(report, depth + 1));
      }
    }
    return nodes;
  }

  Widget _personCard(OrgPerson person, int depth) {
    return Container(
      margin: EdgeInsets.only(left: depth * 24.0, bottom: 8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(
          color: depth == 0
              ? person.divisionColor.withValues(alpha: 0.3)
              : OnyxColorTokens.divider,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: person.divisionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _roleIcon(person.role),
                    color: person.divisionColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OnyxColorTokens.textPrimary,
                        ),
                      ),
                      Text(
                        person.role,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: OnyxColorTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: person.divisionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: person.divisionColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    person.division,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: person.divisionColor,
                    ),
                  ),
                ),
                if (person.reports.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => person.expanded = !person.expanded),
                    child: Icon(
                      person.expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: OnyxColorTokens.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 12,
                      color: OnyxColorTokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      person.email,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: OnyxColorTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 12,
                      color: OnyxColorTokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      person.phone,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: OnyxColorTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (person.reports.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${person.reports.length} direct report'
                    '${person.reports.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: OnyxColorTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) {
    final r = role.toLowerCase();
    if (r.contains('owner') || r.contains('ceo') || r.contains('captain')) {
      return Icons.workspace_premium_rounded;
    }
    if (r.contains('operations manager') && !r.contains('site') &&
        !r.contains('response') && !r.contains('admin') &&
        !r.contains('guard')) {
      return Icons.adjust_rounded;
    }
    if (r.contains('site')) {
      return Icons.apartment_rounded;
    }
    if (r.contains('response') || r.contains('team leader')) {
      return Icons.flash_on_rounded;
    }
    if (r.contains('admin')) {
      return Icons.settings_rounded;
    }
    if (r.contains('guard') || r.contains('supervisor')) {
      return Icons.shield_rounded;
    }
    return Icons.person_rounded;
  }

  // ── Tab 1 — By division ───────────────────────────────────────────────────

  Widget _byDivisionView() {
    final groups = _collectDivisionGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          _divisionGroup(groups[i]),
          if (i != groups.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<_DivisionGroup> _collectDivisionGroups() {
    final groups = <String, _DivisionGroup>{};
    void visit(OrgPerson person) {
      if (person != _root && person != _opsManager) {
        groups.putIfAbsent(
          person.division,
          () => _DivisionGroup(
            name: person.division,
            color: person.divisionColor,
            members: <OrgPerson>[],
          ),
        );
        groups[person.division]!.members.add(person);
      }
      for (final report in person.reports) {
        visit(report);
      }
    }

    visit(_root);
    return groups.values.toList(growable: false);
  }

  Widget _divisionGroup(_DivisionGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: group.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: group.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: group.color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: group.color,
                ),
              ),
              const Spacer(),
              Text(
                '${group.members.length} member'
                '${group.members.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: OnyxColorTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final member in group.members) _personCard(member, 0),
      ],
    );
  }
}

class _DivisionGroup {
  final String name;
  final Color color;
  final List<OrgPerson> members;

  const _DivisionGroup({
    required this.name,
    required this.color,
    required this.members,
  });
}

// ── Seed data ───────────────────────────────────────────────────────────────

OrgPerson _seedOrgTree() {
  const siteOps = OnyxColorTokens.accentCyanTrue;
  const responseOps = OnyxColorTokens.accentAmber;
  const adminOps = OnyxColorTokens.brand;
  const guardOps = OnyxColorTokens.accentGreen;

  final siteLeaders = <OrgPerson>[
    OrgPerson(
      name: 'John Smith',
      role: 'Site Controller (North Region)',
      division: 'Site Operations',
      divisionColor: siteOps,
      email: 'john.smith@onyx.ops',
      phone: '+27 82 555 0141',
    ),
    OrgPerson(
      name: 'Emma Watson',
      role: 'Site Controller (Central Region)',
      division: 'Site Operations',
      divisionColor: siteOps,
      email: 'emma.watson@onyx.ops',
      phone: '+27 82 555 0142',
    ),
    OrgPerson(
      name: 'Michael Brown',
      role: 'Site Controller (South Region)',
      division: 'Site Operations',
      divisionColor: siteOps,
      email: 'michael.brown@onyx.ops',
      phone: '+27 82 555 0143',
    ),
    OrgPerson(
      name: 'Sophia Lee',
      role: 'Site Controller (East Region)',
      division: 'Site Operations',
      divisionColor: siteOps,
      email: 'sophia.lee@onyx.ops',
      phone: '+27 82 555 0144',
    ),
  ];

  final responseLeaders = <OrgPerson>[
    OrgPerson(
      name: 'Jackson Cole',
      role: 'Team Leader (Rapid Response)',
      division: 'Response Operations',
      divisionColor: responseOps,
      email: 'jackson.cole@onyx.ops',
      phone: '+27 82 555 0151',
    ),
    OrgPerson(
      name: 'Victoria Stone',
      role: 'Team Leader (Tactical Response)',
      division: 'Response Operations',
      divisionColor: responseOps,
      email: 'victoria.stone@onyx.ops',
      phone: '+27 82 555 0152',
    ),
  ];

  final guardSupervisors = <OrgPerson>[
    OrgPerson(
      name: 'Rachel Green',
      role: 'Guard Supervisor (Alpha Team)',
      division: 'Guard Operations',
      divisionColor: guardOps,
      email: 'rachel.green@onyx.ops',
      phone: '+27 82 555 0161',
    ),
    OrgPerson(
      name: 'Tom Harris',
      role: 'Guard Supervisor (Bravo Team)',
      division: 'Guard Operations',
      divisionColor: guardOps,
      email: 'tom.harris@onyx.ops',
      phone: '+27 82 555 0162',
    ),
    OrgPerson(
      name: 'Nina Patel',
      role: 'Guard Supervisor (Delta Team)',
      division: 'Guard Operations',
      divisionColor: guardOps,
      email: 'nina.patel@onyx.ops',
      phone: '+27 82 555 0163',
    ),
  ];

  final divisionManagers = <OrgPerson>[
    OrgPerson(
      name: 'Sarah Mitchell',
      role: 'Site Operations Manager',
      division: 'Site Operations',
      divisionColor: siteOps,
      email: 'sarah.mitchell@onyx.ops',
      phone: '+27 82 555 0130',
      reports: siteLeaders,
    ),
    OrgPerson(
      name: "James O'Connor",
      role: 'Response Operations Manager',
      division: 'Response Operations',
      divisionColor: responseOps,
      email: 'james.oconnor@onyx.ops',
      phone: '+27 82 555 0131',
      reports: responseLeaders,
    ),
    OrgPerson(
      name: 'Lisa Thompson',
      role: 'Admin Operations Manager',
      division: 'Administrative Operations',
      divisionColor: adminOps,
      email: 'lisa.thompson@onyx.ops',
      phone: '+27 82 555 0132',
    ),
    OrgPerson(
      name: 'Mike Wilson',
      role: 'Guard Operations Manager',
      division: 'Guard Operations',
      divisionColor: guardOps,
      email: 'mike.wilson@onyx.ops',
      phone: '+27 82 555 0133',
      reports: guardSupervisors,
    ),
  ];

  final opsManager = OrgPerson(
    name: 'Marcus Chen',
    role: 'Operations Manager',
    division: 'Executive',
    divisionColor: OnyxColorTokens.brand,
    email: 'marcus.chen@onyx.ops',
    phone: '+27 82 555 0120',
    reports: divisionManagers,
  );

  return OrgPerson(
    name: 'The Captain',
    role: 'Owner / CEO',
    division: 'Executive',
    divisionColor: OnyxColorTokens.accentAmber,
    email: 'captain@onyx.ops',
    phone: '+27 82 555 0100',
    reports: <OrgPerson>[opsManager],
  );
}
