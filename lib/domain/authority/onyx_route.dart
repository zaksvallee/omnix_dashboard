// lib/domain/authority/onyx_route.dart

import 'package:flutter/material.dart';

/// Authoritative ONYX route enum.
/// This is the ONLY route definition allowed in the system.
enum OnyxRoute {
  dashboard('/dashboard', 'Dashboard', Icons.dashboard_rounded),
  operations('/operations', 'Operations', Icons.security_rounded),
  clients('/clients', 'Clients', Icons.business_rounded),
  guards('/guards', 'Guards', Icons.groups_rounded),
  intelligence('/intelligence', 'Intelligence', Icons.psychology_rounded),
  hr('/hr', 'HR', Icons.badge_rounded),
  settings('/settings', 'Settings', Icons.settings_rounded),
  help('/help', 'Help', Icons.help_outline_rounded);

  final String path;
  final String label;
  final IconData icon;

  const OnyxRoute(this.path, this.label, this.icon);

  /// Resolve enum from GoRouter location
  static OnyxRoute fromLocation(String location) {
    return OnyxRoute.values.firstWhere(
      (route) => location.startsWith(route.path),
      orElse: () => OnyxRoute.dashboard,
    );
  }
}
