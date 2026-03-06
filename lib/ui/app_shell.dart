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
          final compactSidebar = constraints.maxWidth < 1480;
          final sidebarWidth = compactSidebar ? 226.0 : 252.0;
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
                      colors: [Color(0xFF091427), Color(0xFF040A16)],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1222), Color(0xFF08101D), Color(0xFF050A14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(right: BorderSide(color: Color(0xFF122B4C))),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1A2E), Color(0xFF0A1425)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF1D3A61)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF35D4FF), Color(0xFF2363FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF021229),
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
                            color: const Color(0xFFE3EEFF),
                            fontSize: compact ? 20 : 23,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (!compact)
                          Text(
                            "Command Platform",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7E95B4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D182B), Color(0xFF0A1324)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF18375A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Operational Fabric",
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE4EEFF),
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Unified command, intelligence, and client surfaces.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7F97B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            child: Text(
              "Operations",
              style: GoogleFonts.inter(
                color: const Color(0xFF6E84A6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          ...navItems.map((item) {
            return _navItem(context, item.label, item.icon, item.route);
          }),
          SizedBox(height: compact ? 10 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0C172A), Color(0xFF091222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF18385A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SOVEREIGN OPERATIONAL CORE",
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB2D6),
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 5),
                    Text(
                      "Command visibility, field control, and forensic trace.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6F85A6),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
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
        margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 3),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 10 : 11,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF123050), Color(0xFF0D223B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : const Color(0x00000000),
          border: Border.all(
            color: isActive ? const Color(0xFF2C619F) : const Color(0x10234667),
          ),
        ),
        child: Row(
          children: [
            if (isActive)
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(right: 8),
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isActive
                      ? const Color(0xFFE6F2FF)
                      : const Color(0xFFA2B2CF),
                  fontSize: 14,
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
