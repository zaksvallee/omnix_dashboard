import 'sla_profile.dart';
import 'sla_tier.dart';

class SLATierFactory {
  static SLAProfile create({
    required String clientId,
    required SLATier tier,
  }) {
    switch (tier) {
      case SLATier.core:
        return SLAProfile(
          slaId: 'SLA-$clientId-core',
          clientId: clientId,
          lowMinutes: 180,
          mediumMinutes: 90,
          highMinutes: 45,
          criticalMinutes: 20,
          lowWeight: 1.0,
          mediumWeight: 1.5,
          highWeight: 2.0,
          criticalWeight: 3.0,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );

      case SLATier.protect:
        return SLAProfile(
          slaId: 'SLA-$clientId-protect',
          clientId: clientId,
          lowMinutes: 120,
          mediumMinutes: 60,
          highMinutes: 30,
          criticalMinutes: 10,
          lowWeight: 1.0,
          mediumWeight: 2.0,
          highWeight: 3.0,
          criticalWeight: 5.0,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );

      case SLATier.sovereign:
        return SLAProfile(
          slaId: 'SLA-$clientId-sovereign',
          clientId: clientId,
          lowMinutes: 90,
          mediumMinutes: 45,
          highMinutes: 20,
          criticalMinutes: 5,
          lowWeight: 1.0,
          mediumWeight: 3.0,
          highWeight: 5.0,
          criticalWeight: 8.0,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );
    }
  }
}
