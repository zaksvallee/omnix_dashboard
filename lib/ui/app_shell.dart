import 'package:flutter/material.dart';

enum OnyxRoute {
  dashboard,
  dispatches,
  events,
  ledger,
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
      body: Row(
        children: [
          _Sidebar(
            currentRoute: currentRoute,
            onRouteChanged: onRouteChanged,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final OnyxRoute currentRoute;
  final ValueChanged<OnyxRoute> onRouteChanged;

  const _Sidebar({
    required this.currentRoute,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF111426),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "ONYX",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _navItem(context, "Dashboard", OnyxRoute.dashboard),
          _navItem(context, "Dispatches", OnyxRoute.dispatches),
          _navItem(context, "Events", OnyxRoute.events),
          _navItem(context, "Ledger", OnyxRoute.ledger),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String label, OnyxRoute route) {
    final isActive = route == currentRoute;

    return GestureDetector(
      onTap: () => onRouteChanged(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isActive ? const Color(0xFF1B1F3A) : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
