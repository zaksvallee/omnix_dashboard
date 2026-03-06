import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum OnyxRoute {
  dashboard,
  clients,
  sites,
  guards,
  dispatches,
  events,
  ledger,
  reports,
}

class AppShell extends StatelessWidget {
  final Widget child;
  final OnyxRoute currentRoute;
  final ValueChanged<OnyxRoute> onRouteChanged;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020611),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactSidebar = constraints.maxWidth < 1440;
          final sidebarWidth = compactSidebar ? 220.0 : 238.0;
          return Row(
            children: [
              _Sidebar(
                width: sidebarWidth,
                compact: compactSidebar,
                currentRoute: currentRoute,
                onRouteChanged: onRouteChanged,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF091427), Color(0xFF030913)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF132A4A).withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final double width;
  final bool compact;
  final OnyxRoute currentRoute;
  final ValueChanged<OnyxRoute> onRouteChanged;

  const _Sidebar({
    required this.width,
    required this.compact,
    required this.currentRoute,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = <({String label, IconData icon, OnyxRoute route})>[
      (
        label: "Dashboard",
        icon: Icons.dashboard_rounded,
        route: OnyxRoute.dashboard,
      ),
      (
        label: "Clients",
        icon: Icons.chat_bubble_rounded,
        route: OnyxRoute.clients,
      ),
      (label: "Sites", icon: Icons.apartment_rounded, route: OnyxRoute.sites),
      (label: "Guards", icon: Icons.security_rounded, route: OnyxRoute.guards),
      (
        label: "Dispatches",
        icon: Icons.flash_on_rounded,
        route: OnyxRoute.dispatches,
      ),
      (label: "Events", icon: Icons.timeline_rounded, route: OnyxRoute.events),
      (
        label: "Ledger",
        icon: Icons.verified_user_rounded,
        route: OnyxRoute.ledger,
      ),
      (
        label: "Reports",
        icon: Icons.summarize_rounded,
        route: OnyxRoute.reports,
      ),
    ];

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1224),
        border: Border(right: BorderSide(color: Color(0xFF153258))),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _SidebarInfoCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF39D5FF), Color(0xFF2D71FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF04142B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ONYX",
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFEAF4FF),
                          fontSize: compact ? 28 : 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          height: 0.92,
                        ),
                      ),
                      Text(
                        "Command Platform",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8CA6CC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SidebarInfoCard(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Operational Fabric",
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE7F0FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Unified command, intelligence, and client surfaces.",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF84A0C5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              "Operations",
              style: GoogleFonts.inter(
                color: const Color(0xFF6B87AE),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...navItems.map((item) {
            return _navItem(context, item.label, item.icon, item.route);
          }),
          const SizedBox(height: 14),
          _SidebarInfoCard(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SOVEREIGN OPERATIONAL CORE",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF97B1D7),
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Command visibility, field control, and forensic trace.",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6D86A8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
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

  Widget _navItem(
    BuildContext context,
    String label,
    IconData icon,
    OnyxRoute route,
  ) {
    final isActive = route == currentRoute;

    return GestureDetector(
      onTap: () => onRouteChanged(route),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: isActive ? const Color(0xFF122A4A) : const Color(0x080C1728),
          border: Border.all(
            color: isActive ? const Color(0xFF2A609F) : const Color(0x163A5D85),
          ),
        ),
        child: Row(
          children: [
            if (isActive)
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF49D0FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              )
            else
              const SizedBox(width: 13),
            Icon(
              icon,
              size: 17,
              color: isActive
                  ? const Color(0xFF49D0FF)
                  : const Color(0xFF7B8DAD),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isActive
                      ? const Color(0xFFE6F2FF)
                      : const Color(0xFFA2B2CF),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF49D0FF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarInfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SidebarInfoCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1B32), Color(0xFF0A1426)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B3A61)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
